(* carried from kanon de40d65 lib/totality.ml, delta: this header line only *)
(** Totality at M0, plan section 6 "Totality".  The module exists at M0
    with the M1 entry point, so structural recursion arrives at M1 as an
    elaborator translation into an elimination with a certificate that is
    checked before the translation, and not as a driver flag.

    tot's guard (kan-lang-tot-pin/lib/totality.ml:188) peels the leading
    lambdas of a stamped body, walks the application spines
    (kan-lang-tot-pin/lib/totality.ml:29 and :41) and answers the first
    formal position whose every recursive call is on a structurally
    smaller argument.  M0 admits no recursion:  the declarations of a
    file are checked in order and a name is added to the environment only
    after its own declaration is checked (SB-D24), so a body that holds
    its own name is [Error (Unbound name)] at the checker and never
    reaches this module.  The M0 guard is therefore the degenerate arm of
    tot's:  it answers no guarded position for a body with no self call,
    and it answers the milestone word for a body that holds one.

    guard is not wired into check_decls or into the elaborator at M0
    (SC-D15).  The suite reaches it through the KNEG self row and
    SPEC.md section 10 records the M1 wiring.

    No shape name appears in this file (SA-D5, gate leg R0-AUDIT):  the
    subterms of a former are read through [Rules.map_shape], which is the
    one total walk over a shape that rules.ml exports.  This file counts
    toward the TRUSTED-LINES budget. *)

let ( let* ) = Result.bind

(** The milestone word.  test/main.ml compares it, so it is written once
    here and nowhere else. *)
let word : string = "structural recursion arrives at M1"

let budget_msg : string = "the totality budget is exhausted"

(** One exhaustive traversal over the thirteen constructors of [Term.t],
    the shape of tot's [peel] and [spine] walks
    (kan-lang-tot-pin/lib/totality.ml:29 and :41) with the two of them
    fused, because M0 reads the body for one fact alone:  does a [Global]
    name equal the name under definition.  The answer travels in the
    error channel, so the walk stops at the first self call and needs no
    accumulator. *)
let rec seek (budget : Budget.t) (name : string) (t : Term.t) : (unit, Error.t) result =
  if Budget.exhausted budget then Error (Error.Budget_exhausted budget_msg)
  else seek_node budget name t

and seek_node (budget : Budget.t) (name : string) (t : Term.t) : (unit, Error.t) result =
  match t with
  | Term.Var _ -> Ok ()
  | Term.Univ _ -> Ok ()
  | Term.Global n ->
      (* SC-M3 site *)
      if String.equal n name then Error (Error.Not_yet word) else Ok ()
  | Term.Lit _ -> Ok ()
  | Term.Auto -> Ok ()
  | Term.Lan (s, d) ->
      let* () = seek_shape budget name s in
      seek budget name d
  | Term.Ran (s, d) ->
      let* () = seek_shape budget name s in
      seek budget name d
  | Term.In (s, a, args) ->
      let* () = seek_shape budget name s in
      let* () = seek_addr budget name a in
      seek_all budget name args
  | Term.Out (s, a, head) ->
      let* () = seek_shape budget name s in
      let* () = seek_addr budget name a in
      seek budget name head
  | Term.Sec (s, legs) ->
      let* () = seek_shape budget name s in
      seek_all budget name (List.map (fun (lg : Term.leg) -> lg.Term.l_body) legs)
  | Term.Elim e ->
      let* () = seek_shape budget name e.Term.e_shape in
      let* () = seek budget name e.Term.e_scrut in
      let* () = seek_motive budget name e.Term.e_motive in
      seek_branches budget name e.Term.e_branches
  | Term.Let (_x, ty, def, body) ->
      let* () = seek budget name ty in
      let* () = seek budget name def in
      seek budget name body
  | Term.Ann (tm, ty) ->
      let* () = seek budget name tm in
      seek budget name ty

(** The subterms of a shape, read through the total walk of rules.ml so
    that no shape name appears here.  The walk answers a shape, which
    this file drops:  the fact it wants already travelled in the error
    channel. *)
and seek_shape (budget : Budget.t) (name : string) (s : Term.t Shape.t) :
    (unit, Error.t) result =
  Rules.map_shape
    (fun (x : Term.t) -> Result.map (fun (() : unit) -> x) (seek budget name x))
    s
  |> Result.map (fun (_s : Term.t Shape.t) -> ())

and seek_addr (budget : Budget.t) (name : string) (a : Term.addr) :
    (unit, Error.t) result =
  Term.as_apt a
  |> Option.fold ~none:(Ok ())
       ~some:(fun ((_q : Quantity.t), (arg : Term.t)) -> seek budget name arg)

and seek_motive (budget : Budget.t) (name : string) (mo : Term.motive option) :
    (unit, Error.t) result =
  mo
  |> Option.fold ~none:(Ok ()) ~some:(fun (m : Term.motive) ->
         seek budget name m.Term.m_body)

and seek_branches (budget : Budget.t) (name : string)
    (brs : (Term.addr * Term.leg) list) : (unit, Error.t) result =
  List.fold_left
    (fun (acc : (unit, Error.t) result) ((a : Term.addr), (lg : Term.leg)) ->
      let* () = acc in
      let* () = seek_addr budget name a in
      seek budget name lg.Term.l_body)
    (Ok ()) brs

and seek_all (budget : Budget.t) (name : string) (ts : Term.t list) :
    (unit, Error.t) result =
  List.fold_left
    (fun (acc : (unit, Error.t) result) (t : Term.t) ->
      let* () = acc in
      seek budget name t)
    (Ok ()) ts

(** The M1 entry point (kan-lang-tot-pin/lib/totality.ml:188).  [guard
    globals name ty body] answers the guarded argument index of a
    structurally recursive definition.  At M0 it answers [Ok None] for a
    body that holds no [Global] name equal to [name], and the milestone
    word for a body that holds one (SC-D15).  [globals] and [ty] are the
    two inputs the M1 rule reads:  the environment gives the shape of a
    constructor and the declared type gives the formals that [peel]
    counts.  Neither is read at M0, and both stand in the signature so
    that M1 is a body edit and not a signature edit at every call site. *)
let guard ?(budget : Budget.t = Budget.unlimited) (globals : Global.t) (name : string)
    (ty : Term.t) (body : Term.t) : (int option, Error.t) result =
  let _ = globals in
  let _ = ty in
  let* () = seek budget name body in
  Ok None
