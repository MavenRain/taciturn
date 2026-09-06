open Taciturn_kernel

let ( let* ) = Result.bind

let axiom (name : string) (ty : Term.t) (globals : Global.t) : Global.t =
  Global.add name (Global.Axiom { Global.ax_ty = ty }) globals

let globals : Global.t =
  Global.initial
  |> axiom "P" (Term.Univ Level.zero)
  |> axiom "p" (Term.Global "P")
  |> axiom "q" (Term.Global "P")
  |> axiom "f" (Rules.arrow Quantity.Many "x" Prim.nat_ty Prim.nat_ty)
  |> axiom "proofFn" (Rules.arrow Quantity.Many "x" (Term.Global "P") Prim.nat_ty)

let application (head : string) (domain : Term.t) (arg : Term.t) : Term.t =
  Term.Out
    (Shape.SPi (Quantity.Many, "x", domain), Term.APt (Quantity.Many, arg), Term.Global head)

let compare_terms (a : Term.t) (b : Term.t) : (bool, Error.t) result =
  let* ty = Check.infer_term globals a in
  let* other_ty = Check.infer_term globals b in
  let ctx : Check.ctx = Check.make globals Budget.unlimited in
  let* () = Check.ensure ctx other_ty ty in
  let* va = Eval.eval globals [] a in
  let* vb = Eval.eval globals [] b in
  Conv.conv Check.ops ctx ~ty va vb

let check (name : string) (expected : bool) (a : Term.t) (b : Term.t) : bool =
  compare_terms a b
  |> Result.fold
       ~ok:(fun (equal : bool) ->
         let ok : bool = Bool.equal equal expected in
         print_endline ("KERNEL " ^ name ^ if ok then " OK" else " FAIL");
         ok)
       ~error:(fun (e : Error.t) ->
         print_endline ("KERNEL " ^ name ^ " FAIL: " ^ Error.to_string e);
         false)

let () =
  let nat (n : int) : Term.t = Term.Lit (Literal.LInt n) in
  let forged (n : int) : Term.t = application "f" (Term.Global "P") (nat n) in
  let natural (n : int) : Term.t = application "f" Prim.nat_ty (nat n) in
  let proof (name : string) : Term.t =
    application "proofFn" (Term.Global "P") (Term.Global name)
  in
  let results : bool list =
    [
      check "actual-head-domain" false (forged 0) (forged 1);
      check "natural-arguments" false (natural 0) (natural 1);
      check "proof-arguments" true (proof "p") (proof "q");
    ]
  in
  exit (if List.for_all Fun.id results then 0 else 1)
