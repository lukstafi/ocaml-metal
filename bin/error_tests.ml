open Ctypes
open Metal

let _Error_handling_with_invalid_library_code =
  let device = Device.create_system_default () in
  
  (* Create a kernel with syntax errors *)
  let invalid_kernel_source = "
    #include <metal_stdlib>
    using namespace metal;
    
    kernel void invalid_kernel(
      this_is_a_syntax_error
      device float *buffer [[buffer(0)]],
      uint index [[thread_position_in_grid]]) {
      buffer[index] = buffer[index] * 2.0;
    }
  " in
  
  let compile_options = CompileOptions.init () in
  
  (* This should fail with a compiler error *)
  try
    let library = Library.on_device device ~source:invalid_kernel_source compile_options in
    ignore library; (* Explicitly ignore to fix warning *)
    Printf.printf "ERROR: Library compilation should have failed but didn't\n";
  with Failure msg ->
    Printf.printf "Expected error occurred: %s\n" 
      (if String.length msg > 100 then String.sub msg 0 100 ^ "..." else msg)

let _Error_handling_with_invalid_function_name =
  let device = Device.create_system_default () in
  
  (* Create a valid kernel *)
  let kernel_source = "
    #include <metal_stdlib>
    using namespace metal;
    
    kernel void test_kernel(device float *buffer [[buffer(0)]],
                           uint index [[thread_position_in_grid]]) {
      buffer[index] = buffer[index] * 2.0;
    }
  " in
  
  let compile_options = CompileOptions.init () in
  let library = Library.on_device device ~source:kernel_source compile_options in
  
  (* Try to get a function that doesn't exist *)
  try
    let func = Library.new_function_with_name library "nonexistent_function" in
    ignore func; (* Explicitly ignore to fix warning *)
    Printf.printf "ERROR: Function lookup should have failed\n";
  with Failure msg ->
    Printf.printf "Expected error occurred: %s\n" msg

let _Buffer_bounds_checking =
  let device = Device.create_system_default () in
  
  (* Create a small buffer *)
  let options = ResourceOptions.storage_mode_shared in
  let buffer_size = 16 in (* only 4 floats *)
  let buffer = Buffer.on_device device ~length:buffer_size options in
  
  (* Test operating within bounds *)
  let contents = Buffer.contents buffer in
  let float_array_ptr = coerce (ptr void) (ptr float) contents in
  
  (* Set values within bounds *)
  for i = 0 to 3 do
    float_array_ptr +@ i <-@ (float_of_int i)
  done;
  
  (* Read back values within bounds *)
  for i = 0 to 3 do
    let value = !@(float_array_ptr +@ i) in
    Printf.printf "Value at index %d: %f\n" i value;
  done
  
  (* NOTE: In OCaml/C, accessing out of bounds doesn't always cause immediate errors
     but it's unsafe behavior that could cause crashes. We're not testing that here. *)


let _Resource_purge_states =
  let device = Device.create_system_default () in
  
  (* Create a buffer *)
  let options = ResourceOptions.storage_mode_shared in
  let buffer_size = 1024 in
  let buffer = Buffer.on_device device ~length:buffer_size options in
  
  (* Test purge state operations *)
  let prev_state = Resource.set_purgeable_state (Buffer.super buffer) Resource.PurgeableState.NonVolatile in
  Printf.printf "Previous purge state: %s\n" 
    (match prev_state with
     | Resource.PurgeableState.KeepCurrent -> "KeepCurrent"
     | NonVolatile -> "NonVolatile"
     | Volatile -> "Volatile"
     | Empty -> "Empty");
    
  let new_state = Resource.set_purgeable_state (Buffer.super buffer) Resource.PurgeableState.Volatile in
  Printf.printf "New purge state after setting to Volatile: %s\n" 
    (match new_state with
     | Resource.PurgeableState.KeepCurrent -> "KeepCurrent"
     | NonVolatile -> "NonVolatile"
     | Volatile -> "Volatile"
     | Empty -> "Empty")

let _Resource_storage_and_cache_modes =
  let device = Device.create_system_default () in
  
  (* Create buffers with different storage modes *)
  let shared_buffer = Buffer.on_device device ~length:1024 
    ResourceOptions.storage_mode_shared in
  let private_buffer = Buffer.on_device device ~length:1024 
    ResourceOptions.storage_mode_private in
  
  (* Test resource properties *)
  let shared_storage = Resource.get_storage_mode (Buffer.super shared_buffer) in
  Printf.printf "Shared buffer storage mode: %s\n"
    (match shared_storage with
     | Resource.StorageMode.Shared -> "Shared"
     | Managed -> "Managed"
     | Private -> "Private"
     | Memoryless -> "Memoryless");
    
  let private_storage = Resource.get_storage_mode (Buffer.super private_buffer) in
  Printf.printf "Private buffer storage mode: %s\n"
    (match private_storage with
     | Resource.StorageMode.Shared -> "Shared"
     | Managed -> "Managed"
     | Private -> "Private"
     | Memoryless -> "Memoryless");
  
  (* Test CPU cache modes *)
  let combined_buffer = Buffer.on_device device ~length:1024 
    ResourceOptions.(storage_mode_shared + cpu_cache_mode_write_combined) in
  
  let cache_mode = Resource.get_cpu_cache_mode (Buffer.super combined_buffer) in
  Printf.printf "Write combined buffer CPU cache mode: %s\n"
    (match cache_mode with
     | Resource.CPUCacheMode.DefaultCache -> "DefaultCache"
     | WriteCombined -> "WriteCombined") 