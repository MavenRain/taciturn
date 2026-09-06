(* fp.mli.  The BN254 scalar field of the brief section 2.  The
   representation stays hidden: 11 limbs, least significant first, base
   2^24, every limb inside [0, 2^24).  Every result is reduced modulo p. *)

type t

val zero : t
val one : t

(* [of_int] answers zero on a negative argument, so it stays total. *)
val of_int : int -> t

(* [of_decimal] answers None on an empty string, on any byte outside the
   ten digits, and on a value of 2^264 or more. *)
val of_decimal : string -> t option

val to_decimal : t -> string

(* The element encoding of both file kinds: 32 bytes, little-endian. *)
val to_bytes_le : t -> string

(* p at the same 32-byte width, as the two headers carry it. *)
val prime_bytes_le : string

val add : t -> t -> t
val sub : t -> t -> t
val mul : t -> t -> t
val neg : t -> t

(* [pow7] costs four products: t2, t4, t6, t7. *)
val pow7 : t -> t

val equal : t -> t -> bool

(* One byte as a one-byte string.  The two writers share this spelling, so
   the r1cs and the wtns files carry the same little-endian bytes. *)
val byte_string : int -> string
