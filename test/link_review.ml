open Taciturn_kernel
open Taciturn_surface

let report (name : string) (ok : bool) : bool =
  print_endline (name ^ if ok then " OK" else " FAIL");
  ok

let disclosure (name : string) (src : string) (expected : string list -> bool) : bool =
  Elab.check src
  |> Result.fold
       ~ok:(fun (rows : (string * Global.entry) list) ->
         report name (expected (Elab.disclosure_lines rows)))
       ~error:(fun (e : Error.t) ->
         prerr_endline (Error.to_string e);
         report name false)

let () =
  let ordinary : bool =
    disclosure "ordinary axiom is visible"
      "axiom arbitrary : Nat\ndef result : Nat := arbitrary"
      (List.equal String.equal [ "arbitrary axiom Nat" ])
  in
  let ledger : bool =
    disclosure "ledger row reports checked type"
      "axiom sound : Nat\naxiom custom : Nat\ndef result : Nat := custom"
      (fun (lines : string list) ->
        match lines with
        | [ first; second ] ->
            String.starts_with ~prefix:"sound axiom Nat | " first
            && String.equal second "custom axiom Nat"
        | [] | _ :: _ -> false)
  in
  exit (if ordinary && ledger then 0 else 1)
