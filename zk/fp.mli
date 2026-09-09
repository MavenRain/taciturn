(** BN254 scalar arithmetic.  Every value has a canonical residue. *)
type t

val zero : t
val one : t
val of_int : int -> t
(** Signed machine integers are reduced modulo the prime. *)
val of_decimal : string -> t option
(** Accepts decimal digits only, with value strictly below the prime.
    At most 77 digits are accepted, including any leading zeroes. *)
val to_decimal : t -> string
val to_bytes_le : t -> string
val prime_bytes_le : string
val add : t -> t -> t
val sub : t -> t -> t
val mul : t -> t -> t
val neg : t -> t
val inv : t -> t
(** The inverse of zero is zero, as specified by the extern ledger. *)
val equal : t -> t -> bool
