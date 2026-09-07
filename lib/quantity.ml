(* carried from kanon c418062 lib/quantity.ml, delta: W algebra retained, upstream path usage extracted into Linear *)
(** Usage marks of the witness fragment of QTT.  [Zero] binders exist
    only at check time (types, proofs) and erase before evaluation.  [W]
    is the witness mark, new at taciturn M0:  the surface reads it from
    the 'w' binder mark (D-M0-3) and the occurrence rule of SPEC.md
    keeps a W occurrence away from a One-stamped and a Many-stamped
    point, with prove as the only exception.  [One] is the linear mark,
    read from the '1' binder mark.  [Many] binders are runtime data and
    an absent binder mark reads as [Many].

    The occurrence rule is NORMATIVE and the addition table is a
    well-formedness check;  both live in SPEC.md and Stage B enforces
    them. *)

type t =
  | Zero
  | W
  | One
  | Many

(** [Zero] absorbs on both sides, which is seven arms.  [W] carries over
    every mark that is not [Zero], which is five arms.  [One] is the
    unit and [Many] is the result of the three remaining pairs.  Seven
    plus five plus one plus three is sixteen, so the table is total with
    no wildcard arm. *)
let mul (a : t) (b : t) : t =
  match (a, b) with
  | Zero, Zero -> Zero
  | Zero, W -> Zero
  | Zero, One -> Zero
  | Zero, Many -> Zero
  | W, Zero -> Zero
  | One, Zero -> Zero
  | Many, Zero -> Zero
  | W, W -> W
  | W, One -> W
  | W, Many -> W
  | One, W -> W
  | Many, W -> W
  | One, One -> One
  | One, Many -> Many
  | Many, One -> Many
  | Many, Many -> Many

let equal (a : t) (b : t) : bool =
  match (a, b) with
  | Zero, Zero -> true
  | W, W -> true
  | One, One -> true
  | Many, Many -> true
  | Zero, W -> false
  | Zero, One -> false
  | Zero, Many -> false
  | W, Zero -> false
  | W, One -> false
  | W, Many -> false
  | One, Zero -> false
  | One, W -> false
  | One, Many -> false
  | Many, Zero -> false
  | Many, W -> false
  | Many, One -> false

(** The four binder marks as the surface spells them.  kanon spells
    [Many] as "w";  the witness mark takes that spelling here, so [Many]
    takes "many" and no two marks share a text. *)
let to_string (q : t) : string =
  match q with
  | Zero -> "0"
  | W -> "w"
  | One -> "1"
  | Many -> "many"
