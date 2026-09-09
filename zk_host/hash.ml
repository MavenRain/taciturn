module Digest = Taciturn_zk.Digest
let ( let* ) = Result.bind
type error = Io of string | Process of Unix.process_status | Output
let signal_name signal = match () with
  | () when signal = Sys.sigkill -> "kill"
  | () when signal = Sys.sigterm -> "term"
  | () when signal = Sys.sigint -> "int"
  | () when signal = Sys.sigsegv -> "segv"
  | () when signal = Sys.sigpipe -> "pipe"
  | () -> Printf.sprintf "ocaml%d" signal
let error_string = function
  | Io message -> "digest-io:" ^ message
  | Process (Unix.WEXITED code) -> Printf.sprintf "digest-hash-exit:%d" code
  | Process (Unix.WSIGNALED signal) -> "digest-hash-signal:" ^ signal_name signal
  | Process (Unix.WSTOPPED signal) -> "digest-hash-stopped:" ^ signal_name signal
  | Output -> "digest-hash-output"
let io f =
  try Ok (f ()) with
  | Sys_error message -> Error (Io message)
  | Unix.Unix_error (error, call, _argument) ->
      Error (Io (call ^ ":" ^ Unix.error_message error))

let file path =
  let* channels = io (fun () -> Unix.open_process_args_full "/usr/bin/shasum"
      [| "/usr/bin/shasum"; "-a"; "256"; "-b"; "--"; path |]
      [| "PATH=/usr/bin:/bin" |]) in
  let from_child, _to_child, errors = channels in
  let output = io (fun () -> In_channel.input_all from_child) in
  let _drained = io (fun () -> In_channel.input_all errors) in
  let* status = io (fun () -> Unix.close_process_full channels) in
  match status with
  | Unix.WEXITED 0 ->
      let* output = output in
      let escaped = String.to_seq path |> Seq.map (function
          | '\n' -> "\\n" | '\\' -> "\\\\" | c -> String.make 1 c)
          |> List.of_seq |> String.concat "" in
      let prefix = if escaped = path then "" else "\\" in
      let hash = String.of_seq (String.to_seq output
          |> Seq.drop (String.length prefix) |> Seq.take 64) in
      if output <> prefix ^ hash ^ " *" ^ escaped ^ "\n" then Error Output
      else Option.to_result ~none:Output (Digest.of_hex hash)
  | Unix.WEXITED _status | Unix.WSIGNALED _status | Unix.WSTOPPED _status ->
      Error (Process status)

let bytes preimage =
  let* path, output = io (fun () -> Filename.open_temp_file "taciturn-digest-" ".bin") in
  let result =
    let* () = io (fun () -> Out_channel.output_string output preimage) in
    let* () = io (fun () -> Out_channel.close output) in
    file path in
  Out_channel.close_noerr output;
  let removed = io (fun () -> Sys.remove path) in
  Result.bind result (fun hash -> Result.map (fun _unit -> hash) removed)
let circuit context c = bytes (Digest.encode context c)
