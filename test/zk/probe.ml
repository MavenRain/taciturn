open Taciturn_zk

let bad message = prerr_endline message; exit 1
let io path = bad (String.concat "" [ "io:"; path ])
let checked r = Result.fold ~ok:Fun.id ~error:(fun e -> bad (Rows.error_string e)) r
let field s = Option.fold ~none:(fun () -> bad "field-literal") ~some:(fun v () -> v)
    (Fp.of_decimal s) ()
let write path bytes =
  try Out_channel.with_open_bin path (fun oc -> Out_channel.output_string oc bytes)
  with Sys_error _m -> io path
let emit prefix built =
  let c = Lower.compile (checked built) in
  let r1cs = R1cs.encode c and wtns = Wtns.encode c in
  write (prefix ^ ".r1cs") r1cs;
  write (prefix ^ ".wtns") wtns

let run = function
  | [ "mul"; x; y; prefix ] -> emit prefix (Circuits.mul (field x) (field y))
  | [ "mimc3"; x; k; prefix ] -> emit prefix (Circuits.mimc3 (field x) (field k))
  | [ "inv"; x; prefix ] -> emit prefix (Circuits.inverse (field x))
  | [ "eq"; x; y; prefix ] -> emit prefix (Circuits.equality (field x) (field y))
  | [ "select"; b; x; y; prefix ] ->
      emit prefix (Circuits.select (field b) (field x) (field y))
  | [ "repeated"; prefix ] -> emit prefix (Circuits.repeated ())
  | [ "cycle"; prefix ] -> emit prefix (Circuits.cycle ())
  | [ "interface"; prefix ] -> emit prefix (Circuits.interface ())
  | [ "fields"; path ] ->
      let lines = try In_channel.with_open_bin path In_channel.input_lines
        with Sys_error _m -> io path in
      List.iter (fun line ->
          match String.split_on_char ' ' line with
          | [ x; y ] ->
              let a, b = field x, field y in
              print_endline (String.concat " "
                  (List.map Fp.to_decimal [ Fp.add a b; Fp.sub a b; Fp.mul a b; Fp.inv a ]))
          | [] | [ _ ] | _ :: _ :: _ :: _ -> bad "field-vector") lines
  | _args -> bad "probe-usage"

let args = Atomic.make []
let () =
  Arg.parse [] (fun arg -> Atomic.set args (arg :: Atomic.get args)) "backend probe";
  run (List.rev (Atomic.get args))
