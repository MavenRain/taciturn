(* wtns.ml.  The .wtns v2 writer of dossier-toolchain section 2: magic,
   version 2, two sections.  Section 1 holds n8 = 32, the prime and the
   count of values;  section 2 holds every value at 32 bytes,
   little-endian, wire 0 first.  n8 equals fs and the count equals the
   r1cs wire count, which is what a reader of the pair checks.  The
   little-endian integer spellings are the ones of the r1cs writer, so the
   two files cannot drift apart. *)

let write (path : string) (values : Fp.t list) : unit =
  let header =
    String.concat ""
      [ R1cs.u32 32; Fp.prime_bytes_le; R1cs.u32 (List.length values) ]
  in
  let body = String.concat "" (List.map Fp.to_bytes_le values) in
  Out_channel.with_open_bin path (fun oc ->
      Out_channel.output_string oc
        (String.concat ""
           [ "wtns";
             R1cs.u32 2;
             R1cs.u32 2;
             R1cs.section 1 header;
             R1cs.section 2 body ]))
