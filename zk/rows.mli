(** Persistent row construction.  Wire 0 is one, followed by public
    outputs, public inputs, private inputs and internal wires. *)
type wire = int
type error =
  | Counts | Wire_count
  | Missing_binding of wire | Duplicate_binding of wire | Invalid_wire of wire
  | Lookup_tag of int | Unsatisfied_row of int
val error_string : error -> string

type row = {
  ql : Fp.t; qr : Fp.t; qo : Fp.t; qm : Fp.t; qc : Fp.t;
  a : wire; b : wire; c : wire; lookup : int;
}
val blank : row
type state
type circuit = private {
  n_pub_out : int; n_pub_in : int; n_priv : int;
  n_wires : int; rows : row list; witness : Fp.t list;
}

val init : n_pub_out:int -> n_pub_in:int -> n_priv:int -> (state, error) result
val bind : state -> wire -> Fp.t -> (state, error) result
val fresh : state -> Fp.t -> (state * wire, error) result
val value : state -> wire -> (Fp.t, error) result
val add_row : state -> row -> (state, error) result
(** All three indices must exist, even when a selector is zero.
    Allocated interface slots may receive their values later. *)
val mul_into : state -> a:wire -> b:wire -> c:wire -> (state, error) result
val mul : state -> wire -> wire -> (state * wire, error) result
val lin : state -> ca:Fp.t -> a:wire -> cb:Fp.t -> b:wire -> k0:Fp.t ->
  (state * wire, error) result
val define : state -> ca:Fp.t -> a:wire -> cb:Fp.t -> b:wire -> k0:Fp.t ->
  c:wire -> (state, error) result
val assert_bit : state -> wire -> (state, error) result
val assert_one : state -> wire -> (state, error) result
val select : state -> bit:wire -> yes:wire -> no:wire -> (state * wire, error) result
(** Includes the booleanity row.  No branch depends on the witness. *)
val inv : state -> wire -> (state * wire, error) result
val equal : state -> wire -> wire -> (state * wire, error) result
(** Inverse and equality advice is constrained, including the zero case. *)
val finish : state -> (circuit, error) result
(** Requires every allocated binding and checks every row on the witness.
    Successful circuits alone may enter lowering and serialization. *)
