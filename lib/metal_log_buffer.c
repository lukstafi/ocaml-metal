/* A native MTLLogState log handler that buffers messages C-side.

   Metal invokes log handlers on its own dispatch threads. A handler built from an OCaml closure
   (as [LogState.add_log_handler] does through a ctypes block) runs OCaml code on those threads:
   the block literal lives in GC-managed memory that Metal keeps a pointer to, and the handler
   competes for the domain lock with a host thread blocked in a Metal wait. The handler installed
   here never touches the OCaml runtime: it copies each message into a mutex-protected C buffer,
   and the host thread drains the buffer when it chooses (after synchronizing).

   Ownership. Metal retains (Block_copy) the handler for as long as the log state lives, and C
   blocks have no disposal hook we can attach to, so the [log_buffer] struct the block captures is
   never freed: it is one small struct per log state. The OCaml handle owns the entries: its
   finalizer frees the pending ones and marks the buffer closed, after which the handler drops
   whatever still arrives. */

#include <Block.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define CAML_NAME_SPACE
#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

struct log_entry {
  char *sub_system; /* NULL when Metal passed nil */
  char *category;   /* NULL when Metal passed nil */
  char *message;
  long level;
};

struct log_buffer {
  pthread_mutex_t mutex;
  struct log_entry *entries;
  size_t len;
  size_t cap;
  size_t dropped; /* entries lost to allocation failure since the last drain */
  int closed;     /* the OCaml handle was finalized */
};

/* Returns a malloc'd copy of the NSString's UTF-8 contents, or NULL for nil. Sets [*failed] when
   the string was non-nil but could not be copied. */
static char *copy_nsstring(id str, int *failed) {
  if (str == nil) return NULL;
  const char *utf8 = ((const char *(*)(id, SEL))objc_msgSend)(str, sel_registerName("UTF8String"));
  char *copy = strdup(utf8 ? utf8 : "");
  if (copy == NULL) *failed = 1;
  return copy;
}

static void free_entry(struct log_entry *e) {
  free(e->sub_system);
  free(e->category);
  free(e->message);
}

/* Runs on a Metal thread: plain C only. */
static void append(struct log_buffer *buf, id sub_system, id category, long level, id message) {
  int failed = 0;
  struct log_entry e;
  e.sub_system = copy_nsstring(sub_system, &failed);
  e.category = copy_nsstring(category, &failed);
  e.message = copy_nsstring(message, &failed);
  if (e.message == NULL && !failed) {
    e.message = strdup("");
    if (e.message == NULL) failed = 1;
  }
  e.level = level;
  pthread_mutex_lock(&buf->mutex);
  if (buf->closed) {
    pthread_mutex_unlock(&buf->mutex);
    free_entry(&e);
    return;
  }
  if (!failed && buf->len == buf->cap) {
    size_t new_cap = buf->cap == 0 ? 64 : buf->cap * 2;
    struct log_entry *grown = realloc(buf->entries, new_cap * sizeof(struct log_entry));
    if (grown == NULL)
      failed = 1;
    else {
      buf->entries = grown;
      buf->cap = new_cap;
    }
  }
  if (failed) {
    buf->dropped++;
    pthread_mutex_unlock(&buf->mutex);
    free_entry(&e);
    return;
  }
  buf->entries[buf->len++] = e;
  pthread_mutex_unlock(&buf->mutex);
}

/* The OCaml handle: a custom block holding the [log_buffer] pointer. */

#define Buffer_val(v) (*((struct log_buffer **)Data_custom_val(v)))

static void finalize_handle(value v) {
  struct log_buffer *buf = Buffer_val(v);
  if (buf == NULL) return;
  pthread_mutex_lock(&buf->mutex);
  for (size_t i = 0; i < buf->len; i++) free_entry(&buf->entries[i]);
  free(buf->entries);
  buf->entries = NULL;
  buf->len = buf->cap = 0;
  buf->closed = 1;
  pthread_mutex_unlock(&buf->mutex);
  /* [buf] itself stays allocated: Metal's copy of the handler block still points at it. */
}

static struct custom_operations log_buffer_ops = {
    "ocaml-metal.log_buffer",   finalize_handle,          custom_compare_default,
    custom_hash_default,        custom_serialize_default, custom_deserialize_default,
    custom_compare_ext_default, custom_fixed_length_default};

/* [install log_state_address] registers the buffering handler on the MTLLogState at that address
   and returns the handle. */
value ocaml_metal_log_buffer_install(value log_state_address) {
  CAMLparam1(log_state_address);
  CAMLlocal1(handle);
  id log_state = (id)(intptr_t)Nativeint_val(log_state_address);
  if (log_state == nil) caml_invalid_argument("LogState.add_buffered_log_handler: nil log state");
  struct log_buffer *buf = calloc(1, sizeof(struct log_buffer));
  if (buf == NULL) caml_raise_out_of_memory();
  if (pthread_mutex_init(&buf->mutex, NULL) != 0) {
    free(buf);
    caml_failwith("LogState.add_buffered_log_handler: pthread_mutex_init failed");
  }
  handle = caml_alloc_custom(&log_buffer_ops, sizeof(struct log_buffer *), 0, 1);
  Buffer_val(handle) = buf;
  /* A stack block; addLogHandler: copies it to the heap (capturing [buf] by value). */
  void (^handler)(id, id, long, id) = ^(id sub_system, id category, long level, id message) {
    append(buf, sub_system, category, level, message);
  };
  ((void (*)(id, SEL, void (^)(id, id, long, id)))objc_msgSend)(
      log_state, sel_registerName("addLogHandler:"), handler);
  CAMLreturn(handle);
}

static value option_of_cstring(const char *s) {
  CAMLparam0();
  CAMLlocal2(str, some);
  if (s == NULL) CAMLreturn(Val_none);
  str = caml_copy_string(s);
  some = caml_alloc_some(str);
  CAMLreturn(some);
}

/* A detached batch, owned by a custom block while it is converted: an allocation that raises
   [Out_of_memory] mid-conversion leaves the batch to this block's finalizer instead of leaking it. */
struct batch {
  struct log_entry *entries;
  size_t len;
};

#define Batch_val(v) ((struct batch *)Data_custom_val(v))

static void free_batch(struct batch *b) {
  for (size_t i = 0; i < b->len; i++) free_entry(&b->entries[i]);
  free(b->entries);
  b->entries = NULL;
  b->len = 0;
}

static void finalize_batch(value v) { free_batch(Batch_val(v)); }

static struct custom_operations batch_ops = {
    "ocaml-metal.log_batch",    finalize_batch,           custom_compare_default,
    custom_hash_default,        custom_serialize_default, custom_deserialize_default,
    custom_compare_ext_default, custom_fixed_length_default};

/* [drain handle] returns [(entries, dropped)]: the entries buffered since the last drain, oldest
   first, as [(sub_system, category, level, message)] tuples, and how many were dropped. */
value ocaml_metal_log_buffer_drain(value handle) {
  CAMLparam1(handle);
  CAMLlocal5(list, cell, tuple, field, result);
  CAMLlocal1(owner);
  struct log_buffer *buf = Buffer_val(handle);
  size_t dropped;
  /* The owner is allocated before anything is detached, so no allocation failure can strand the
     batch. */
  owner = caml_alloc_custom(&batch_ops, sizeof(struct batch), 0, 1);
  Batch_val(owner)->entries = NULL;
  Batch_val(owner)->len = 0;
  /* Detach the batch under the lock; build OCaml values outside it (allocation may run the GC). */
  pthread_mutex_lock(&buf->mutex);
  Batch_val(owner)->entries = buf->entries;
  Batch_val(owner)->len = buf->len;
  dropped = buf->dropped;
  buf->entries = NULL;
  buf->len = buf->cap = 0;
  buf->dropped = 0;
  pthread_mutex_unlock(&buf->mutex);
  list = Val_emptylist;
  for (size_t k = Batch_val(owner)->len; k > 0; k--) {
    /* Re-read through [owner] each time: a GC may move the custom block. */
    tuple = caml_alloc_tuple(4);
    field = option_of_cstring(Batch_val(owner)->entries[k - 1].sub_system);
    Store_field(tuple, 0, field);
    field = option_of_cstring(Batch_val(owner)->entries[k - 1].category);
    Store_field(tuple, 1, field);
    Store_field(tuple, 2, Val_long(Batch_val(owner)->entries[k - 1].level));
    field = caml_copy_string(Batch_val(owner)->entries[k - 1].message);
    Store_field(tuple, 3, field);
    cell = caml_alloc_small(2, Tag_cons);
    Field(cell, 0) = tuple;
    Field(cell, 1) = list;
    list = cell;
  }
  free_batch(Batch_val(owner));
  result = caml_alloc_tuple(2);
  Store_field(result, 0, list);
  Store_field(result, 1, Val_long(dropped));
  CAMLreturn(result);
}
