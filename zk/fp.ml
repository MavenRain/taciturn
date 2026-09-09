(** The Stage C backend uses the pin's Zarith dependency.  The separate
    Stage 0 limb implementation remains an arithmetic and encoding oracle.
    This is host arithmetic, preceding the RField accelerator. *)
type t = Z.t

let decimal s = String.fold_left
    (fun n c -> Z.add (Z.mul n (Z.of_int 10))
        (Z.of_int (Char.code c - Char.code '0'))) Z.zero s
let prime =
  decimal "21888242871839275222246405745257275088548364400416034343698204186575808495617"
let zero = Z.zero
let one = Z.one
let reduce n = Z.erem n prime
let of_int n = reduce (Z.of_int n)
let of_decimal s =
  let n = decimal s in
  match () with
  | () when String.length s = 0 || String.length s > 77 -> None
  | () when not (String.for_all (fun c -> c >= '0' && c <= '9') s) -> None
  | () when Z.compare n prime < 0 -> Some n
  | () -> None

let to_decimal = Z.to_string
let bytes n = String.of_seq
    (Seq.take 32 (Seq.append (String.to_seq (Z.to_bits n)) (Seq.repeat '\000')))
let to_bytes_le = bytes
let prime_bytes_le = bytes prime
let add a b = reduce (Z.add a b)
let sub a b = reduce (Z.sub a b)
let mul a b = reduce (Z.mul a b)
let neg a = sub zero a
let equal = Z.equal
let inv a = if equal a zero then zero else Z.invert a prime
