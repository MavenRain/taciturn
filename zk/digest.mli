(** Versioned circuit identity before L1 lowering.  Witness values never
    enter the encoding.  Row order and wire numbering are significant. *)
type sha256
val of_hex : string -> sha256 option
val to_hex : sha256 -> string
(** Exactly 64 hexadecimal digits; accepted upper case becomes lower case. *)

type imports = { zk : sha256; sym : sha256; pre : sha256 }
type error =
  | Compiler_version
  | Width_name
  | Width_value of string
  | Duplicate_width of string
val error_string : error -> string
type context
val context : compiler_version:string -> widths:(string * int) list ->
  imports:imports -> (context, error) result
(** Widths are unsigned 32-bit field-slot counts, sorted by name.
    Zero-width entries are allowed.  Empty or duplicate names are refused.
    The caller supplies the complete width table and actual import hashes;
    this layer cannot check those against a typed program or host files. *)
val encode : context -> Rows.circuit -> string
(** Canonical bytes including the format and hash names, BN254 prime,
    compiler version, three named import hashes, width table, interface
    counts, allocated wire count and every ordered row before lowering. *)
