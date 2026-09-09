(** Fixed-width unsigned integers.  A value is reduced modulo
    2 ^ (8 * width), the same truncation as spike/rows/r1cs.ml.  Callers
    supply counts, wire ids or in-memory section lengths that zk/rows.ml
    bounds by limit = 0xffffffff. *)
let unsigned width n = String.of_seq
    (Seq.take width (Seq.append
        (String.to_seq (Z.to_bits (Z.extract (Z.of_int n) 0 (8 * width))))
        (Seq.repeat '\000')))
let u32 n = unsigned 4 n
let u64 n = unsigned 8 n
let section kind body = String.concat "" [ u32 kind; u64 (String.length body); body ]
