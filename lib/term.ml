(* carried from kanon de40d65 lib/term.ml, delta: this header line only *)
(** The kernel term at M0, plan section 4.  Thirteen constructors;  two of
    them form types.  The whole sum is declared at Stage A and every
    constructor past M0 is refused by rules.ml or by check.ml with its
    milestone name (D-M0-2), so each later milestone is a loud edit to an
    exhaustive match rather than a new constructor.

    The shape of a former is written as [t Shape.t], so no shape name
    appears in this file (SA-D5).

    [motive] mirrors tot's record field for field,
    kan-lang-tot-pin/lib/term.ml:88-102.  Its one convention, stated there
    and kept here: [m_idx] is in declaration order, outermost binder
    first, and [m_body] is scoped under [m_idx] and then under [m_self],
    so de Bruijn index 0 inside [m_body] is [m_self].

    Addresses.  [APt] is the point address and carries the argument.
    [ALeg] is the leg address, used by the collection shape and by the
    pair shape.  [ACtor] is the constructor address of the two recursive
    shapes and arrives at M1 and M2. *)

type addr =
  | APt of Quantity.t * t
  | ALeg of int
  | ACtor of string

and leg = {
  l_binders : (Quantity.t * string) list;
  l_body : t;
}

and elim = {
  e_shape : t Shape.t;
  e_scrut : t;
  e_scrut_q : Quantity.t;
  e_motive : motive option;
  e_branches : (addr * leg) list;
}

and motive = {
  m_ind : string option;
  m_idx : string list;
  m_self : string;
  m_body : t;
}

and t =
  | Var of int
  | Univ of Level.t
  | Lan of t Shape.t * t
  | Ran of t Shape.t * t
  | In of t Shape.t * addr * t list
  | Elim of elim
  | Sec of t Shape.t * leg list
  | Out of t Shape.t * addr * t
  | Let of string * t * t * t
  | Ann of t * t
  | Global of string
  | Lit of Literal.t
  | Auto

(** The two type formers (R-Q2).  spec_count.ml prints the length of this
    list, so a third former moves the R0 count. *)
let formers : string list = [ "Lan"; "Ran" ]

(** The four schema constructors: two introductions and two eliminations,
    one pair per former. *)
let schema : string list = [ "In"; "Elim"; "Sec"; "Out" ]

(** Total views on an address (Stage B).  Plan section 11 bans a partial
    projection, so a rule asks one of these and folds the [option]. *)

let as_apt (a : addr) : (Quantity.t * t) option =
  match a with
  | APt (q, arg) -> Some (q, arg)
  | ALeg _ -> None
  (* M1 Stage G, brief 3.5:  a constructor address carries no point. *)
  | ACtor _ -> None

let as_aleg (a : addr) : int option =
  match a with
  | ALeg k -> Some k
  | APt (_, _) -> None
  (* M1 Stage G, brief 3.5:  the constructor address is not a leg. *)
  | ACtor _ -> None

(** M1 Stage G:  the third view, which the mu pack asks for the
    constructor name of an introduction (rules.ml [mu_intro_in]). *)
let as_actor (a : addr) : string option =
  match a with
  | ACtor c -> Some c
  | APt (_, _) -> None
  | ALeg _ -> None
