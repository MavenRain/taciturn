(** L1 lowering and wire pruning, kept together so serializers cannot
    accidentally combine pre-pruning witnesses with post-pruning rows. *)
type lc = (Rows.wire * Fp.t) list
type constraint_ = { a : lc; b : lc; c : lc }
type t = private {
  n_pub_out : int; n_pub_in : int; n_priv : int;
  n_wires : int; constraints : constraint_ list; witness : Fp.t list;
}
val compile : Rows.circuit -> t
