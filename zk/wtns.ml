(** WTNS v2, ported from spike/rows/wtns.ml. *)
let encode (c : Lower.t) =
  let header = Binary.u32 32 ^ Fp.prime_bytes_le ^ Binary.u32 c.n_wires in
  let body = String.concat "" (List.map Fp.to_bytes_le c.witness) in
  String.concat "" [ "wtns"; Binary.u32 2; Binary.u32 2;
                      Binary.section 1 header; Binary.section 2 body ]
