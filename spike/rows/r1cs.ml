(* r1cs.ml.  The .r1cs v1 writer of dossier-toolchain section 1: magic,
   version, section count, header section 1, constraint section 2, and the
   wire-to-label section 3 whose label of a wire is the wire id.  Every
   integer is little-endian and every element is fs = 32 bytes. *)

let u32 (n : int) : string =
  String.concat "" (List.init 4 (fun i -> Fp.byte_string (n lsr (8 * i))))

let u64 (n : int) : string =
  String.concat "" (List.init 8 (fun i -> Fp.byte_string (n lsr (8 * i))))

(* One section: the type, the size of the body in bytes, then the body. *)
let section (ty : int) (body : string) : string =
  String.concat "" [ u32 ty; u64 (String.length body); body ]

(* One linear combination: the count of nonzero terms, then one pair of a
   wire id and a value per term, ascending by wire id. *)
let lc_bytes (l : Lower.lc) : string =
  String.concat ""
    (u32 (List.length l)
    :: List.map (fun (w, v) -> String.concat "" [ u32 w; Fp.to_bytes_le v ]) l)

let write (path : string) (c : Row.circuit) (cs : Lower.cst list) : unit =
  let header =
    String.concat ""
      [ u32 32;
        Fp.prime_bytes_le;
        u32 c.n_wires;
        u32 c.c_pub_out;
        u32 c.c_pub_in;
        u32 c.c_priv;
        u64 c.n_wires;
        u32 (List.length cs) ]
  in
  let body =
    String.concat ""
      (List.map
         (fun (k : Lower.cst) ->
           String.concat "" [ lc_bytes k.ca; lc_bytes k.cb; lc_bytes k.cc ])
         cs)
  in
  let labels = String.concat "" (List.init c.n_wires (fun w -> u64 w)) in
  Out_channel.with_open_bin path (fun oc ->
      Out_channel.output_string oc
        (String.concat ""
           [ "r1cs";
             u32 1;
             u32 3;
             section 1 header;
             section 2 body;
             section 3 labels ]))
