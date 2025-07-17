open Ctypes
open Metal

let test_indirect_command_buffer_basics () =
  let device = Device.create_system_default () in

  (* Skip if device doesn't support indirect command buffers *)
  let pipeline_desc = ComputePipelineDescriptor.create () in
  ComputePipelineDescriptor.set_support_indirect_command_buffers pipeline_desc true;

  (* Create kernel *)
  let kernel_source =
    {|
    #include <metal_stdlib>
    using namespace metal;

    kernel void double_values(device float *buffer [[buffer(0)]],
                              uint index [[thread_position_in_grid]]) {
      buffer[index] = buffer[index] * 2.0;
    }
  |}
  in

  let compile_options = CompileOptions.init () in
  let library = Library.on_device device ~source:kernel_source compile_options in
  let func = Library.new_function_with_name library "double_values" in
  ComputePipelineDescriptor.set_compute_function pipeline_desc func;
  (* Log pipeline descriptor via sexp conversion *)
  Format.printf "Pipeline descriptor: %a\n%!" Sexplib0.Sexp.pp_hum
    (ComputePipelineDescriptor.sexp_of_t pipeline_desc);

  (* Create compute pipeline state *)
  let pipeline_state, _ = ComputePipelineState.on_device_with_descriptor device pipeline_desc in

  let supports_icb = ComputePipelineState.get_support_indirect_command_buffers pipeline_state in
  Printf.printf "Pipeline supports indirect command buffers: %b\n" supports_icb;

  if supports_icb then (
    (* Create ICB descriptor *)
    let icb_desc = IndirectCommandBufferDescriptor.create () in
    IndirectCommandBufferDescriptor.set_command_types icb_desc
      IndirectCommandType.concurrent_dispatch;
    IndirectCommandBufferDescriptor.set_inherit_pipeline_state icb_desc false;
    IndirectCommandBufferDescriptor.set_max_kernel_buffer_bind_count icb_desc 1;

    (* Create indirect command buffer *)
    let icb =
      (* NOTE: storage_mode_shared fails on CI machines (paravirtual devices) *)
      IndirectCommandBuffer.on_device_with_descriptor device icb_desc ~max_command_count:1
        ~options:ResourceOptions.storage_mode_private
    in

    (* Get indirect compute command *)
    let cmd = IndirectCommandBuffer.indirect_compute_command_at_index icb 0 in

    (* Set up the command *)
    IndirectComputeCommand.set_compute_pipeline_state cmd pipeline_state;

    (* Create data buffer *)
    let buffer_size = 16 in
    (* 4 floats *)
    let buffer = Buffer.on_device device ~length:buffer_size ResourceOptions.storage_mode_shared in

    (* Initialize buffer *)
    let ptr = Buffer.contents buffer |> coerce (ptr void) (ptr float) in
    for i = 0 to 3 do
      ptr +@ i <-@ float_of_int (i + 1)
    done;

    (* Buffer.did_modify_range buffer { Range.location = 0; length = buffer_size }; *)

    (* Set buffer in command *)
    IndirectComputeCommand.set_kernel_buffer cmd ~index:0 buffer;

    (* Set dispatch dimensions *)
    IndirectComputeCommand.concurrent_dispatch_threadgroups cmd
      ~threadgroups_per_grid:{ Size.width = 4; height = 1; depth = 1 }
      ~threads_per_threadgroup:{ Size.width = 1; height = 1; depth = 1 };

    (* Create command buffer and encoder *)
    let queue = CommandQueue.on_device device in
    let cmd_buffer = CommandBuffer.on_queue queue in
    let compute_encoder = ComputeCommandEncoder.on_buffer cmd_buffer in

    (* Execute the indirect command buffer *)
    ComputeCommandEncoder.execute_commands_in_buffer compute_encoder icb
      { Range.location = 0; length = 1 };

    (* End encoding and commit *)
    ComputeCommandEncoder.end_encoding compute_encoder;
    CommandBuffer.commit cmd_buffer;
    CommandBuffer.wait_until_completed cmd_buffer;

    (* Verify results *)
    for i = 0 to 3 do
      let value = !@(ptr +@ i) in
      Printf.printf "buffer[%d] = %g\n" i value
    done)

let () = test_indirect_command_buffer_basics ()
