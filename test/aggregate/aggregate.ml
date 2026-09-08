open Taciturn_kernel
open Taciturn_surface

let ( let* ) = Result.bind

let kernel (value : ('a, Error.t) result) : ('a, string) result =
  Result.map_error Error.to_string value

let require (ok : bool) (message : string) : (unit, string) result =
  if ok then Ok () else Error message

let checked (source : string) : (Global.t, string) result =
  let* parsed = kernel (Parser.parse source) in
  let* again = kernel (Parser.parse (Parser.print parsed)) in
  let* () = require (parsed = again) "surface roundtrip changed the program" in
  let* rows = kernel (Elab.check source) in
  Ok (List.fold_left
    (fun (globals : Global.t) ((name : string), (entry : Global.entry)) ->
      Global.add name entry globals)
    Global.initial rows)

let computes (source : string) (answers : (string * int) list) () :
    (unit, string) result =
  let* globals = checked source in
  List.fold_left
    (fun (acc : (unit, string) result) ((name : string), (want : int)) ->
      let* () = acc in
      let* value = kernel (Eval.eval globals [] (Term.Global name)) in
      let* term = kernel (Eval.quote globals 0 value) in
      let expected : Term.t = Term.Lit (Literal.LInt (Bignum.of_int want)) in
      require (term = expected) (name ^ " evaluated to " ^ Pp.term [] term))
    (Ok ()) answers

let accepts (source : string) () : (unit, string) result =
  checked source |> Result.map (fun _globals -> ())

let rejects (prefix : string) (source : string) () : (unit, string) result =
  Elab.check source |> Result.fold
    ~ok:(fun _rows -> Error "accepted an invalid program")
    ~error:(fun (error : Error.t) ->
      let text : string = Error.to_string error in
      require (String.starts_with ~prefix text) ("unexpected diagnostic: " ^ text))

(* A refusal whose wording is the point of the row, so the row compares the
   whole diagnostic and not its tag alone. *)
let rejects_exactly (message : string) (source : string) () : (unit, string) result =
  Elab.check source |> Result.fold
    ~ok:(fun _rows -> Error "accepted an invalid program")
    ~error:(fun (error : Error.t) ->
      let text : string = Error.to_string error in
      require (String.equal text message) ("unexpected diagnostic: " ^ text))

let forged_injection (tag : int) (width : int) () : (unit, string) result =
  let context : Check.ctx = Check.make Global.initial Budget.unlimited in
  Elab.elab context (Parser.SInj (tag, width, Parser.SNat Bignum.zero))
  |> Result.fold
       ~ok:(fun _term -> Error "elaborated an invalid injection index")
       ~error:(fun (error : Error.t) ->
         let text : string = Error.to_string error in
         require (String.starts_with ~prefix:"wrong leg:" text) text)

let tests : (string * (unit -> (unit, string) result)) list =
  [ "pair-projections", computes
      "def pair : Nat * Nat := (3, 7)\n\
       def first : Nat := pair.1\n\
       def second : Nat := pair.2"
      ["first", 3; "second", 7];
    "tuple-projections", computes
      "def Triple : Type 0 := prod (Nat, Nat, Nat)\n\
       def triple : Triple := tuple (11, 13, 17)\n\
       def first : Nat := triple.0\n\
       def middle : Nat := triple.1\n\
       def last : Nat := triple.2"
      ["first", 11; "middle", 13; "last", 17];
    "dependent-fibre-lambda", computes
      "def packed : (0 A : Type 0) * A := ((x : Nat) -> Nat, fun (x : Nat) => natAdd x 1)\n\
       def result : Nat := packed.2 41"
      ["result", 42];
    "dependent-second-projection", accepts
      "def unpack : (p : (0 A : Type 0) * A) -> p.1 :=\n\
         fun (p : (0 A : Type 0) * A) => p.2";
    "dependent-projection-family", accepts
      "def unpack : (0 A : Type 0) -> (0 B : (x : A) -> Type 0) ->\n\
         (p : (a : A) * B a) -> B p.1 :=\n\
         fun (0 A : Type 0) (0 B : (x : A) -> Type 0) (p : (a : A) * B a) => p.2";
    "dependent-pair-eta", accepts
      "axiom F : (p : (0 A : Type 0) * A) -> Type 0\n\
       def eta : (p : (0 A : Type 0) * A) -> (v : F p) ->\n\
         F ((p.1, p.2) : (0 A : Type 0) * A) :=\n\
         fun (p : (0 A : Type 0) * A) (v : F p) => v";
    "dependent-pair-distinct", rejects "mismatch:"
      "axiom F : (p : (0 A : Type 0) * A) -> Type 0\n\
       axiom value : F ((Nat, 0) : (0 A : Type 0) * A)\n\
       def different : F ((Nat, 1) : (0 A : Type 0) * A) := value";
    "dependent-outer-binder", computes
      "def pack : (0 A : Type 0) -> (x : A) -> (0 B : Type 0) * B :=\n\
         fun (0 A : Type 0) (x : A) => (A, x)\n\
       def result : Nat := (pack Nat 23).2"
      ["result", 23];
    "projection-under-outer-binders", computes
      "def unpack : (0 A : Type 0) -> (outer : A) -> (p : Nat * A) -> A :=\n\
         fun (0 A : Type 0) (outer : A) (p : Nat * A) => p.2\n\
       def result : Nat := unpack Nat 5 (7, 11)"
      ["result", 11];
    "renamed-dependent-binders", computes
      "def pack : (0 A : Type 0) -> (x : A) -> (0 B : Type 0) * B :=\n\
         fun (0 T : Type 0) (value : T) => (T, value)\n\
       def result : Nat := (pack Nat 151).2"
      ["result", 151];
    "nested-pair", computes
      "def nested : Nat * (Nat * Nat) := (19, (23, 29))\n\
       def result : Nat := nested.2.1"
      ["result", 23];
    "pair-in-application", computes
      "def first : (p : Nat * Nat) -> Nat := fun (p : Nat * Nat) => p.1\n\
       def result : Nat := first (31, 37)"
      ["result", 31];
    "pair-in-annotation", computes
      "def result : Nat := ((41, 43) : Nat * Nat).2"
      ["result", 43];
    "pair-in-let", computes
      "def result : Nat := let pair : Nat * Nat := (47, 53) in pair.1"
      ["result", 47];
    "pair-through-let-result", computes
      "def pair : Nat * Nat := let x : Nat := 59 in (x, 61)\n\
       def result : Nat := pair.1"
      ["result", 59];
    "pair-in-tuple", computes
      "def packed : prod (Nat * Nat, Nat) := tuple ((67, 71), 73)\n\
       def result : Nat := packed.0.2"
      ["result", 71];
    "tuple-in-pair", computes
      "def packed : Nat * prod (Nat, Nat) := (79, tuple (83, 89))\n\
       def result : Nat := packed.2.0"
      ["result", 83];
    "heterogeneous-injections", accepts
      "def Choice : Type 0 := sum (Nat, Nat * Nat)\n\
       def left : Choice := inj 0 of 2 97\n\
       def right : Choice := inj 1 of 2 (101, 103)";
    "injection-in-application", accepts
      "def accept : (x : sum (Nat, Nat * Nat)) -> Nat := fun (x : sum (Nat, Nat * Nat)) => 0\n\
       def result : Nat := accept (inj 1 of 2 (107, 109))";
    "tuple-lambda-and-injection", accepts
      "def packed : prod ((x : Nat) -> Nat, sum (Nat, Nat * Nat)) :=\n\
         tuple (fun (x : Nat) => x, inj 1 of 2 (113, 127))";
    "empty-collections", accepts
      "def Empty : Type 0 := sum ()\n\
       def Unit : Type 0 := prod ()\n\
       def unit : Unit := tuple ()\n\
       def eliminate : (e : Empty) -> Nat := fun (e : Empty) => absurd e";
    "witness-pair-point", accepts
      "def pack : (w x : Nat) -> (w y : Nat) * Nat := fun (w x : Nat) => (x, 0)";
    "witness-pair-public-fibre", computes
      "def pack : (w x : Nat) -> (w y : Nat) * Nat := fun (w x : Nat) => (x, 139)\n\
       def result : Nat := (pack 149).2"
      ["result", 139];
    "erased-pair-point", computes
      "def pack : (0 x : Nat) -> (0 y : Nat) * Nat := fun (0 x : Nat) => (x, 131)\n\
       def result : Nat := (pack 137).2"
      ["result", 131];
    "pair-witness-leak", rejects "quantity:"
      "def leak : (w x : Nat) -> Nat * Nat := fun (w x : Nat) => (x, 0)";
    "tuple-witness-leak", rejects "quantity:"
      "def leak : (w x : Nat) -> prod (Nat, Nat) := fun (w x : Nat) => tuple (x, 0)";
    "injection-witness-leak", rejects "quantity:"
      "def leak : (w x : Nat) -> sum (Nat, Nat) := fun (w x : Nat) => inj 0 of 2 x";
    "pair-projection-witness-leak", rejects "quantity:"
      "def leak : (p : (w x : Nat) * Nat) -> Nat := fun (p : (w x : Nat) * Nat) => p.1";
    "pair-projection-erased-leak", rejects "quantity:"
      "def leak : (p : (0 x : Nat) * Nat) -> Nat := fun (p : (0 x : Nat) * Nat) => p.1";
    "pair-projection-binder-name", rejects_exactly
      "quantity: the binder y is marked 0 and the point is stamped many, so \
       the occurrence rule of SPEC.md section 3.1 does not read it there"
      "def p : (0 y : Nat) * Nat := (5, 9)\ndef leak : Nat := p.1";
    "tuple-linear-duplication", rejects "usage:"
      "def duplicate : (1 x : Nat) -> prod (Nat, Nat) := fun (1 x : Nat) => tuple (x, x)";
    "pair-wrong-first-leg", rejects "wrong leg:"
      "def pair : Nat * Nat := (1, 2)\ndef result : Nat := pair.0";
    "pair-wrong-last-leg", rejects "wrong leg:"
      "def pair : Nat * Nat := (1, 2)\ndef result : Nat := pair.3";
    "tuple-out-of-range", rejects "wrong leg:"
      "def pair : prod (Nat, Nat) := tuple (1, 2)\ndef result : Nat := pair.2";
    "sum-projection", rejects "mismatch:"
      "def choice : sum (Nat, Nat) := inj 0 of 2 1\ndef result : Nat := choice.1";
    "nat-projection", rejects "mismatch:" "def result : Nat := 1.0";
    "pair-without-expectation", rejects "cannot infer:"
      "def result : Nat := (1, 2).1";
    "pair-at-tuple-type", rejects "mismatch:"
      "def result : prod (Nat, Nat) := (1, 2)";
    "tuple-at-pair-type", rejects "mismatch:"
      "def result : Nat * Nat := tuple (1, 2)";
    "tuple-width", rejects "mismatch:"
      "def result : prod (Nat, Nat) := tuple (1)";
    "tuple-width-nested-pair", rejects "mismatch:"
      "def result : prod (Nat * Nat, Nat, Nat) := tuple ((1, 2), 3)";
    "injection-width", rejects "mismatch:"
      "def result : sum (Nat, Nat) := inj 0 of 3 1";
    "injection-hostile-width", rejects "mismatch:"
      "def result : sum (Nat, Nat) := inj 0 of 999999999999999999 1";
    "injection-tag", rejects "wrong leg:"
      "def result : sum (Nat, Nat) := inj 2 of 2 1";
    "injection-hostile-tag", rejects "wrong leg:"
      "def result : sum (Nat, Nat) := inj 999999999999999999 of 2 1";
    "injection-negative-tag", forged_injection (-1) 2;
    "injection-negative-width", forged_injection 0 (-1);
    "injection-payload", rejects "mismatch:"
      "def result : sum (Nat, Nat * Nat) := inj 1 of 2 1";
    "absurd-nonempty", rejects "missing branch:"
      "def result : (s : sum (Nat)) -> Nat := fun (s : sum (Nat)) => absurd s";
    "dependent-fibre-mismatch", rejects "mismatch:"
      "def result : (0 A : Type 0) * A := (Nat, fun (x : Nat) => x)";
    "sum-element-not-type", rejects "universe:"
      "def result : Type 0 := sum (Nat, 1)";
    "product-element-not-type", rejects "universe:"
      "def result : Type 0 := prod (1, Nat)" ]

let report ((name : string), (run : unit -> (unit, string) result)) : bool =
  run () |> Result.fold
    ~ok:(fun () -> print_endline ("AGGREGATE " ^ name ^ " OK"); true)
    ~error:(fun (message : string) ->
      print_endline ("AGGREGATE " ^ name ^ " FAIL: " ^ message); false)

let () =
  let results : bool list = List.map report tests in
  let passed : int = List.length (List.filter Fun.id results) in
  let total : int = List.length results in
  print_endline (Printf.sprintf "AGGREGATE %d/%d" passed total);
  exit (if Int.equal passed total then 0 else 1)
