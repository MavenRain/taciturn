(** R1CS v1, ported from spike/rows/r1cs.ml.  Pure encoding leaves file
    handling to the host boundary. *)
let lc_bytes (lc : Lower.lc) = String.concat ""
    (Binary.u32 (List.length lc) :: List.map (fun (w, v) ->
         Binary.u32 w ^ Fp.to_bytes_le v) lc)

let encode (c : Lower.t) =
  let header = String.concat ""
      [ Binary.u32 32; Fp.prime_bytes_le; Binary.u32 c.n_wires;
        Binary.u32 c.n_pub_out; Binary.u32 c.n_pub_in; Binary.u32 c.n_priv;
        Binary.u64 c.n_wires; Binary.u32 (List.length c.constraints) ] in
  let body = String.concat "" (List.map (fun (k : Lower.constraint_) ->
      lc_bytes k.a ^ lc_bytes k.b ^ lc_bytes k.c) c.constraints) in
  let labels = String.concat "" (List.init c.n_wires Binary.u64) in
  String.concat "" [ "r1cs"; Binary.u32 1; Binary.u32 3;
                      Binary.section 1 header; Binary.section 2 body;
                      Binary.section 3 labels ]
