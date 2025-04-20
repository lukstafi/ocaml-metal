open Metal

(* This file contains helpers for setting up code coverage and exercising parts of the API that
   might be hard to cover in regular tests *)

(* Helper to exercise all Range functionality *)
let test_range_functions () =
  let range = Range.make ~location:10 ~length:20 in
  let range_value = Range.from_struct range in
  Printf.printf "Range: location=%d, length=%d\n" range_value.location range_value.length;
  let range2 = Range.to_value range_value in
  let range_value2 = Range.from_struct range2 in
  assert (range_value.location = range_value2.location);
  assert (range_value.length = range_value2.length);
  Printf.printf "Range conversion works correctly\n"

(* Helper to test all ResourceOptions combinations *)
let test_resource_options () =
  let combinations =
    [
      (ResourceOptions.storage_mode_shared, "storage_mode_shared");
      (ResourceOptions.storage_mode_managed, "storage_mode_managed");
      (ResourceOptions.storage_mode_private, "storage_mode_private");
      (ResourceOptions.storage_mode_memoryless, "storage_mode_memoryless");
      (ResourceOptions.cpu_cache_mode_default_cache, "cpu_cache_mode_default_cache");
      (ResourceOptions.cpu_cache_mode_write_combined, "cpu_cache_mode_write_combined");
      (ResourceOptions.hazard_tracking_mode_default, "hazard_tracking_mode_default");
      (ResourceOptions.hazard_tracking_mode_untracked, "hazard_tracking_mode_untracked");
      (ResourceOptions.hazard_tracking_mode_tracked, "hazard_tracking_mode_tracked");
    ]
  in

  List.iter
    (fun (option, name) ->
      Printf.printf "ResourceOption %s: %s\n" name
        (Sexplib0.Sexp.to_string_hum @@ ResourceOptions.sexp_of_t option))
    combinations;

  (* Test combine operator *)
  let combined =
    ResourceOptions.(
      storage_mode_private + cpu_cache_mode_write_combined + hazard_tracking_mode_tracked)
  in
  Printf.printf "Combined options: %s\n"
    (Sexplib0.Sexp.to_string_hum @@ ResourceOptions.sexp_of_t combined);

  (* Test make function with all options *)
  let made =
    ResourceOptions.make ~storage_mode:ResourceOptions.storage_mode_private
      ~cpu_cache_mode:ResourceOptions.cpu_cache_mode_write_combined
      ~hazard_tracking_mode:ResourceOptions.hazard_tracking_mode_tracked ()
  in
  Printf.printf "Made options: %s\n"
    (Sexplib0.Sexp.to_string_hum @@ ResourceOptions.sexp_of_t made)

(* Helper to test all PipelineOption combinations *)
let test_pipeline_options () =
  let combinations =
    [
      (PipelineOption.none, "none");
      (PipelineOption.argument_info, "argument_info");
      (PipelineOption.buffer_type_info, "buffer_type_info");
      (PipelineOption.fail_on_binary_archive_miss, "fail_on_binary_archive_miss");
    ]
  in

  List.iter
    (fun (option, name) ->
      Printf.printf "PipelineOption %s: %s\n" name
        (Sexplib0.Sexp.to_string_hum @@ PipelineOption.sexp_of_t option))
    combinations;

  (* Test combine operator *)
  let combined =
    PipelineOption.(argument_info + buffer_type_info)
  in
  Printf.printf "Combined pipeline options: %s\n"
    (Sexplib0.Sexp.to_string_hum @@ PipelineOption.sexp_of_t combined)

(* Helper to test all Language versions *)
let test_language_versions () =
  let versions =
    [
      (CompileOptions.LanguageVersion.version_1_0, "version_1_0");
      (CompileOptions.LanguageVersion.version_1_1, "version_1_1");
      (CompileOptions.LanguageVersion.version_1_2, "version_1_2");
      (CompileOptions.LanguageVersion.version_2_0, "version_2_0");
      (CompileOptions.LanguageVersion.version_2_1, "version_2_1");
      (CompileOptions.LanguageVersion.version_2_2, "version_2_2");
      (CompileOptions.LanguageVersion.version_2_3, "version_2_3");
      (CompileOptions.LanguageVersion.version_2_4, "version_2_4");
      (CompileOptions.LanguageVersion.version_3_0, "version_3_0");
      (CompileOptions.LanguageVersion.version_3_1, "version_3_1");
      (CompileOptions.LanguageVersion.version_3_2, "version_3_2");
    ]
  in

  List.iter
    (fun (version, name) ->
      Printf.printf "Language version %s: %s\n" name
        (Sexplib0.Sexp.to_string_hum @@ CompileOptions.LanguageVersion.sexp_of_t version))
    versions

(* Helper to test CommandBuffer handlers *)
let test_command_buffer_handlers () =
  let device = Device.create_system_default () in
  let queue = CommandQueue.on_device device in
  let cmd_buffer = CommandBuffer.on_queue queue in

  (* Test scheduled handler *)
  let scheduled_called = ref false in
  CommandBuffer.add_scheduled_handler cmd_buffer (fun _ ->
      scheduled_called := true;
      Printf.printf "Scheduled handler called\n");

  (* Test completed handler *)
  let completed_called = ref false in
  CommandBuffer.add_completed_handler cmd_buffer (fun _ ->
      completed_called := true;
      Printf.printf "Completed handler called\n");

  (* Commit and wait *)
  CommandBuffer.commit cmd_buffer;
  CommandBuffer.wait_until_completed cmd_buffer;

  Printf.printf "Scheduled handler was called: %b\n" !scheduled_called;
  Printf.printf "Completed handler was called: %b\n" !completed_called

(* Helper to test debug functions *)
let test_debug_functions () =
  let device = Device.create_system_default () in
  let queue = CommandQueue.on_device device in

  (* Test command buffer debug groups *)
  let cmd_buffer = CommandBuffer.on_queue queue in
  CommandBuffer.push_debug_group cmd_buffer "Test debug group";
  CommandBuffer.pop_debug_group cmd_buffer;

  (* Test encoder debug groups and signposts *)
  let cmd_buffer2 = CommandBuffer.on_queue queue in
  let compute_encoder = ComputeCommandEncoder.on_buffer cmd_buffer2 in

  ComputeCommandEncoder.push_debug_group compute_encoder "Test encoder debug group";
  ComputeCommandEncoder.insert_debug_signpost compute_encoder "Test signpost";
  ComputeCommandEncoder.pop_debug_group compute_encoder;
  ComputeCommandEncoder.end_encoding compute_encoder;

  (* Test buffer debug markers *)
  let buffer = Buffer.on_device device ~length:1024 ResourceOptions.storage_mode_shared in
  Buffer.add_debug_marker buffer ~marker:"Test buffer marker" { Range.location = 0; length = 1024 };
  Buffer.remove_all_debug_markers buffer;

  Printf.printf "Debug functions executed successfully\n"

(* Main test that exercises all the helpers *)
let%expect_test "Comprehensive coverage test" =
  Printf.printf "Starting comprehensive coverage test...\n";

  test_range_functions ();
  test_resource_options ();
  test_pipeline_options ();
  test_language_versions ();
  test_command_buffer_handlers ();
  test_debug_functions ();

  Printf.printf "Comprehensive coverage test completed\n";
  [%expect
    {|
    Starting comprehensive coverage test...
    Range: location=10, length=20
    Range conversion works correctly
    ResourceOption storage_mode_shared: 0
    ResourceOption storage_mode_managed: 16
    ResourceOption storage_mode_private: 32
    ResourceOption storage_mode_memoryless: 48
    ResourceOption cpu_cache_mode_default_cache: 0
    ResourceOption cpu_cache_mode_write_combined: 1
    ResourceOption hazard_tracking_mode_default: 0
    ResourceOption hazard_tracking_mode_untracked: 256
    ResourceOption hazard_tracking_mode_tracked: 512
    Combined options: 545
    Made options: 545
    PipelineOption none: 0
    PipelineOption argument_info: 1
    PipelineOption buffer_type_info: 2
    PipelineOption fail_on_binary_archive_miss: 4
    Combined pipeline options: 3
    Language version version_1_0: 0
    Language version version_1_1: 65537
    Language version version_1_2: 65538
    Language version version_2_0: 131072
    Language version version_2_1: 131073
    Language version version_2_2: 131074
    Language version version_2_3: 131075
    Language version version_2_4: 131076
    Language version version_3_0: 196608
    Language version version_3_1: 196609
    Language version version_3_2: 196610
    Scheduled handler called
    Completed handler called
    Scheduled handler was called: true
    Completed handler was called: true
    Debug functions executed successfully
    Comprehensive coverage test completed
  |}]
