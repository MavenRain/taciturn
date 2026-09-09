open Taciturn_zk
module Hash = Taciturn_zk_host.Hash
let require error = Result.fold ~ok:Fun.id ~error:(fun e ->
    prerr_endline (error e); exit 1)
let field s = Option.fold ~none:(fun () -> prerr_endline "field"; exit 1)
    ~some:(fun v () -> v) (Fp.of_decimal s) ()
let hash c = Option.fold ~none:(fun () -> prerr_endline "hash"; exit 1)
    ~some:(fun h () -> h) (Digest.of_hex (String.make 64 c)) ()
let context = require Digest.error_string (Digest.context
    ~compiler_version:"taciturn-test-v1" ~widths:[ "Field", 1; "Bit", 1; "Unit", 0 ]
    ~imports:{ zk = hash '0'; sym = hash '1'; pre = hash '2' })
let run = function
  | [ mode; kind; x; y ] ->
      let built = match kind with
        | "mul" -> Circuits.mul (field x) (field y)
        | "mimc3" -> Circuits.mimc3 (field x) (field y)
        | "inverse" -> Circuits.inverse (field x)
        | "equality" -> Circuits.equality (field x) (field y)
        | "select" -> Circuits.select (field x) (field y) (field y)
        | _kind -> prerr_endline "kind"; exit 1 in
      let c = require Rows.error_string built in
      (match mode with
       | "preimage" -> print_string (Digest.encode context c)
       | "hash" -> print_endline (Digest.to_hex (require Hash.error_string (Hash.circuit context c)))
       | _mode -> prerr_endline "mode"; exit 1)
  | _args -> prerr_endline "digest-probe-usage"; exit 64
let args = Atomic.make []
let () =
  Arg.parse [] (fun arg -> Atomic.set args (arg :: Atomic.get args)) "digest probe";
  run (List.rev (Atomic.get args))
