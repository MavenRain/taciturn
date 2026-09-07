open Taciturn_kernel
open Taciturn_surface

let ( let* ) = Result.bind

let kernel (value : ('a, Error.t) result) : ('a, string) result =
  Result.map_error Error.to_string value

let require (ok : bool) (message : string) : (unit, string) result =
  if ok then Ok () else Error message

let accepts (source : string) : (unit, string) result =
  Elab.check source |> kernel |> Result.map (fun _rows -> ())

let refuses (prefix : string) (result : ('a, Error.t) result) : (unit, string) result =
  Result.fold
    ~ok:(fun _value -> Error "accepted an invalid program")
    ~error:(fun (error : Error.t) ->
      let text : string = Error.to_string error in
      require (String.starts_with ~prefix text) ("unexpected diagnostic: " ^ text))
    result

let rejects (prefix : string) (source : string) : (unit, string) result =
  refuses prefix (Elab.check source)

let nat (value : int) : Term.t = Term.Lit (Literal.LInt (Bignum.of_int value))

let lambda (q : Quantity.t) (name : string) (domain : Term.t) (body : Term.t) : Term.t =
  Term.Sec
    (Shape.SPi (q, name, domain),
     [{ Term.l_binders = [q, name]; l_body = body }])

let check_core (term : Term.t) (ty : Term.t) : (unit, Error.t) result =
  let* _universe = Check.infer_term Global.initial ty in
  let* expected = Eval.eval Global.initial [] ty in
  Check.check_term Global.initial term expected

let modulus : string =
  "21888242871839275222246405745257275088548364400416034343698204186575808495617"

let nat_computes () : (unit, string) result =
  let source : string =
    "def modulus : Nat := " ^ modulus ^ "\n"
    ^ "def squared : Nat := natMul modulus modulus\n"
    ^ "def successor : Nat := natAdd modulus 1\n"
    ^ "def difference : Nat := natSub squared squared\n"
    ^ "def truncated : Nat := natSub 1 modulus\n"
    ^ "def aboveHost : Nat := natAdd 4611686018427387903 1\n"
  in
  let* parsed = kernel (Parser.parse source) in
  let* reparsed = kernel (Parser.parse (Parser.print parsed)) in
  let* () = require (parsed = reparsed) "large literals changed during printing" in
  let* rows = kernel (Elab.check source) in
  let globals : Global.t =
    List.fold_left
      (fun (acc : Global.t) ((name : string), (entry : Global.entry)) ->
        Global.add name entry acc)
      Global.initial rows
  in
  let expected : (string * string) list =
    [ "modulus", modulus;
      "squared",
      "479095176016622842441988045216678740792775727437641695839672483225394008897735544758717141888410194952926680628591158570087660349541859529148712708210689";
      "successor",
      "21888242871839275222246405745257275088548364400416034343698204186575808495618";
      "difference", "0"; "truncated", "0"; "aboveHost", "4611686018427387904" ]
  in
  List.fold_left
    (fun (acc : (unit, string) result) ((name : string), (want : string)) ->
      let* () = acc in
      let* value = kernel (Eval.eval globals [] (Term.Global name)) in
      let* quoted = kernel (Eval.quote globals 0 value) in
      let got : string = Pp.term [] quoted in
      require (String.equal got want) (name ^ " evaluated to " ^ got))
    (Ok ()) expected

let numeric_boundaries () : (unit, string) result =
  let* () = refuses "mismatch:" (Check.infer_term Global.initial (nat (-1))) in
  let context : Check.ctx = Check.make Global.initial Budget.unlimited in
  let* () =
    List.fold_left
      (fun (acc : (unit, string) result) (level : int) ->
        let* () = acc in
        refuses "universe:" (Elab.elab context (Parser.SType level)))
      (Ok ()) [-1; Stdlib.max_int - 1; Stdlib.max_int]
  in
  let* () = rejects "line " ("axiom excessive : Type " ^ modulus) in
  let* () = accepts "axiom elevated : Type 999999999999999999" in
  let* () = rejects "line " ("def excessive : Nat := 0." ^ modulus) in
  let* () = rejects "line " ("def excessive : Nat := inj " ^ modulus ^ " of 2 0") in
  rejects "line " ("def excessive : Nat := inj 0 of " ^ modulus ^ " 0")

let one_surface : (string * bool * string) list =
  [ "one-identity", true,
    "def identity : (1 x : Nat) -> Nat := fun (1 x : Nat) => x";
    "one-unused", false,
    "def unused : (1 x : Nat) -> Nat := fun (1 x : Nat) => 0";
    "one-duplicate", false,
    "def duplicate : (1 x : Nat) -> Nat := fun (1 x : Nat) => natAdd x x";
    "one-annotation-only", false,
    "axiom F : (0 index : Nat) -> Type 0\n\
     axiom inhabit : (0 index : Nat) -> F index\n\
     def unused : (1 x : Nat) -> F x := fun (1 x : Nat) => (inhabit x : F x)";
    "one-unrestricted-consumer", false,
    "def consume : (y : Nat) -> Nat := fun (y : Nat) => y\n\
     def passed : (1 x : Nat) -> Nat := fun (1 x : Nat) => consume x";
    "one-witness-consumer", false,
    "def consume : (w y : Nat) -> Nat := fun (w y : Nat) => 0\n\
     def passed : (1 x : Nat) -> Nat := fun (1 x : Nat) => consume x";
    "one-eager-let-alias", false,
    "def duplicate : (1 x : Nat) -> Nat := fun (1 x : Nat) => let y : Nat := x in x";
    "one-linear-let-alias", true,
    "def once : (1 x : Nat) -> Nat := fun (1 x : Nat) => let y : Nat := x in y";
    "one-closure-capture", true,
    "axiom applyOnce : (1 f : (y : Nat) -> Nat) -> Nat\n\
     def once : (1 x : Nat) -> Nat := fun (1 x : Nat) => applyOnce (fun (y : Nat) => x)";
    "one-closure-duplicate", false,
    "axiom applyOnce : (1 f : (y : Nat) -> Nat) -> Nat\n\
     def duplicate : (1 x : Nat) -> Nat := fun (1 x : Nat) =>\n\
       let f : (y : Nat) -> Nat := (fun (y : Nat) => x) in\n\
       let first : Nat := applyOnce f in applyOnce f";
    "one-erased-capture", true,
    "axiom F : (0 index : Nat) -> Type 0\n\
     def once : (1 x : Nat) -> Nat := fun (1 x : Nat) =>\n\
       let f : (0 p : F x) -> Nat := (fun (0 p : F x) => 0) in x";
    "one-binder-inside-witness-mode", true,
    "def discard : (w f : (1 x : Nat) -> Nat) -> Nat :=\n\
       fun (w f : (1 x : Nat) -> Nat) => 0\n\
     def result : Nat := discard (fun (1 x : Nat) => x)" ]

let branch (number : int) (q : Quantity.t) (body : Term.t) : Term.addr * Term.leg =
  Term.ALeg number, { Term.l_binders = [q, "payload"]; l_body = body }

let eliminate (size : int) (scrutinee : Term.t)
    (branches : (Term.addr * Term.leg) list) : Term.t =
  Term.Elim
    { Term.e_shape = Shape.SColl size; e_scrut = scrutinee;
      e_scrut_q = Quantity.Many; e_motive = None; e_branches = branches }

let branch_program (right : Term.t) : Term.t * Term.t =
  let both : Term.t = Rules.sum_ty [Prim.nat_ty; Prim.nat_ty] in
  let body : Term.t =
    eliminate 2 (Term.Var 0)
      [branch 0 Quantity.Many (Term.Var 2); branch 1 Quantity.Many right]
  in
  lambda Quantity.One "x" Prim.nat_ty (lambda Quantity.Many "tag" both body),
  Rules.arrow Quantity.One "x" Prim.nat_ty
    (Rules.arrow Quantity.Many "tag" both Prim.nat_ty)

let branch_paths () : (unit, string) result =
  let good, ty = branch_program (Term.Var 2) in
  let bad, bad_ty = branch_program (nat 0) in
  let* () = kernel (check_core good ty) in
  let* () = refuses "usage:" (check_core bad bad_ty) in
  let both : Term.t = Rules.sum_ty [Prim.nat_ty; Prim.nat_ty] in
  let payload (body : Term.t) : Term.t =
    lambda Quantity.Many "tag" both
      (eliminate 2 (Term.Var 0)
         [branch 0 Quantity.One body; branch 1 Quantity.One body])
  in
  let payload_ty : Term.t = Rules.arrow Quantity.Many "tag" both Prim.nat_ty in
  let* () = kernel (check_core (payload (Term.Var 0)) payload_ty) in
  refuses "usage:" (check_core (payload (nat 0)) payload_ty)

let unreachable_path () : (unit, string) result =
  let empty : Term.t = Term.Ann (Rules.sum_ty [], Term.Univ Level.one) in
  let ty : Term.t =
    Rules.arrow Quantity.Many "empty" empty
      (Rules.arrow Quantity.One "x" Prim.nat_ty Prim.nat_ty)
  in
  let body : Term.t =
    lambda Quantity.Many "empty" empty
      (lambda Quantity.One "x" Prim.nat_ty (eliminate 0 (Term.Var 1) []))
  in
  let* () = kernel (check_core body ty) in
  let closure_ty : Term.t =
    Rules.arrow Quantity.One "x" Prim.nat_ty
      (Rules.arrow Quantity.Many "empty" empty Prim.nat_ty)
  in
  let closure : Term.t =
    lambda Quantity.One "x" Prim.nat_ty
      (lambda Quantity.Many "empty" empty (eliminate 0 (Term.Var 0) []))
  in
  refuses "usage:" (check_core closure closure_ty)

let mixed_returning_paths () : (unit, string) result =
  let empty : Term.t = Term.Ann (Rules.sum_ty [], Term.Univ Level.one) in
  let both : Term.t = Rules.sum_ty [Prim.nat_ty; Prim.nat_ty] in
  let ty : Term.t =
    Rules.arrow Quantity.Many "empty" empty
      (Rules.arrow Quantity.Many "tag" both
         (Rules.arrow Quantity.One "x" Prim.nat_ty Prim.nat_ty))
  in
  let body (duplicate : bool) : Term.t =
    let stopped : Term.t =
      if duplicate then
        Term.Let ("first", Prim.nat_ty, Term.Var 1,
          Term.Let ("second", Prim.nat_ty, Term.Var 2,
            eliminate 0 (Term.Var 5) []))
      else
        Term.Let ("first", Prim.nat_ty, Term.Var 1,
          eliminate 0 (Term.Var 4) [])
    in
    lambda Quantity.Many "empty" empty
      (lambda Quantity.Many "tag" both
         (lambda Quantity.One "x" Prim.nat_ty
            (eliminate 2 (Term.Var 1)
               [branch 0 Quantity.Many (Term.Var 1); branch 1 Quantity.Many stopped])))
  in
  let* () = kernel (check_core (body false) ty) in
  refuses "usage:" (check_core (body true) ty)

let witness_rules () : (unit, string) result =
  let* () = accepts
    "def consume : (w y : Nat) -> Nat := fun (w y : Nat) => 0\n\
     def passed : (w x : Nat) -> Nat := fun (w x : Nat) => consume x" in
  let* () = rejects "quantity:"
    "axiom consume : (1 y : Nat) -> Nat\n\
     def leaked : (w x : Nat) -> Nat := fun (w x : Nat) => consume x" in
  let* () = rejects "quantity:"
    "def leaked : (w x : Nat) -> Nat := fun (w x : Nat) => natAdd x 0" in
  accepts
    "axiom Circuit : Type 0\naxiom Public : Type 0\naxiom Witness : Type 0\n\
     axiom Proof : (R : Circuit) -> (x : Public) -> Type 0\n\
     axiom prove : (R : Circuit) -> (x : Public) -> (w wit : Witness) -> Proof R x\n\
     def declassified : (R : Circuit) -> (x : Public) -> (w wit : Witness) -> Proof R x :=\n\
       fun (R : Circuit) (x : Public) (w wit : Witness) => prove R x wit"

let recursive_body (argument : int) : Term.t =
  let domain : Term.t = Term.Global "N" in
  let arrow : Term.t Shape.t = Shape.SPi (Quantity.Many, "n", domain) in
  let call : Term.t =
    Term.Out (arrow, Term.APt (Quantity.Many, Term.Var argument), Term.Global "self")
  in
  let body : Term.t =
    Term.Elim
      { Term.e_shape = Shape.SMu ("N", []); e_scrut = Term.Var 0;
        e_scrut_q = Quantity.Many;
        e_motive = Some { Term.m_ind = Some "N"; m_idx = [];
                          m_self = "selfValue"; m_body = domain };
        e_branches = [Term.ACtor "succ",
                      { Term.l_binders = [Quantity.Many, "smaller"]; l_body = call }] }
  in
  lambda Quantity.Many "n" domain body

let totality () : (unit, string) result =
  let guard (body : Term.t) : (int option, Error.t) result =
    Totality.guard Global.initial "self" (Term.Global "N") body
  in
  let* position = kernel (guard (recursive_body 0)) in
  let* () = require (Option.equal Int.equal position (Some 0)) "decreasing call lost its guard" in
  let* none = kernel (guard (nat 0)) in
  let* () = require (Option.is_none none) "constant body acquired a recursion guard" in
  let* () = refuses "termination:" (guard (Term.Global "self")) in
  let* () = refuses "termination:" (guard (recursive_body 1)) in
  refuses "budget:"
    (Totality.guard ~budget:(Budget.of_poll (fun () -> true))
       Global.initial "self" (Term.Global "N") (recursive_body 0))

let report ((name : string), (run : unit -> (unit, string) result)) : bool =
  run () |> Result.fold
    ~ok:(fun () -> print_endline ("REPIN " ^ name ^ " OK"); true)
    ~error:(fun (message : string) ->
      print_endline ("REPIN " ^ name ^ " FAIL: " ^ message); false)

let () =
  let surface_tests : (string * (unit -> (unit, string) result)) list =
    List.map (fun ((name : string), (valid : bool), (source : string)) ->
      name, (fun () -> if valid then accepts source else rejects "usage:" source))
      one_surface
  in
  let tests : (string * (unit -> (unit, string) result)) list =
    ["large-nat-computation", nat_computes; "numeric-boundaries", numeric_boundaries;
     "branch-paths", branch_paths; "unreachable-path", unreachable_path;
     "mixed-returning-paths", mixed_returning_paths;
     "witness-rules", witness_rules; "totality", totality] @ surface_tests
  in
  let results : bool list = List.map report tests in
  let passed : int = List.length (List.filter Fun.id results) in
  let total : int = List.length results in
  print_endline (Printf.sprintf "REPIN %d/%d" passed total);
  exit (if Int.equal passed total then 0 else 1)
