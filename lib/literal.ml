(* carried from kanon de40d65 lib/literal.ml, delta: this header line only *)
(** String and integer literal values. A closed leaf with no dependency
    on any other kernel module (M3 Stage A). *)

type t =
  | LString of string
  | LInt of int

let equal (a : t) (b : t) : bool =
  match (a, b) with
  | LString s1, LString s2 -> String.equal s1 s2
  | LInt n1, LInt n2 -> Int.equal n1 n2
  | LString _, LInt _ -> false
  | LInt _, LString _ -> false
