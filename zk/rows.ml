(** Production row IR, adapted from spike/rows/row.ml.  Checked operations
    replace delayed faults and missing-value defaults. *)
module Wires = Map.Make (Int)
let ( let* ) = Result.bind
type wire = int
type error =
  | Counts | Wire_count
  | Missing_binding of wire | Duplicate_binding of wire | Invalid_wire of wire
  | Lookup_tag of int | Unsatisfied_row of int

let error_string = function
  | Counts -> "counts"
  | Wire_count -> "wire-count"
  | Missing_binding w -> Printf.sprintf "missing-binding:%d" w
  | Duplicate_binding w -> Printf.sprintf "duplicate-binding:%d" w
  | Invalid_wire w -> Printf.sprintf "invalid-wire:%d" w
  | Lookup_tag tag -> Printf.sprintf "lookup-tag:%d" tag
  | Unsatisfied_row i -> Printf.sprintf "unsatisfied-row:%d" i

type row = {
  ql : Fp.t; qr : Fp.t; qo : Fp.t; qm : Fp.t; qc : Fp.t;
  a : wire; b : wire; c : wire; lookup : int;
}
type state = {
  next : int; rev_rows : row list; values : Fp.t Wires.t;
  out : int; input : int; priv : int;
}
type circuit = {
  n_pub_out : int; n_pub_in : int; n_priv : int;
  n_wires : int; rows : row list; witness : Fp.t list;
}

let limit = 0xffffffff
let init ~n_pub_out ~n_pub_in ~n_priv =
  if n_pub_out < 1 || n_pub_out > limit - 1
     || n_pub_in < 0 || n_pub_in > limit - 1 - n_pub_out
     || n_priv < 0 || n_priv > limit - 1 - n_pub_out - n_pub_in
  then Error Counts
  else Ok { next = 1 + n_pub_out + n_pub_in + n_priv; rev_rows = [];
            values = Wires.singleton 0 Fp.one;
            out = n_pub_out; input = n_pub_in; priv = n_priv }

let valid st w = if w < 0 || w >= st.next then Error (Invalid_wire w) else Ok ()
let bind st w v =
  let* () = valid st w in
  if Wires.mem w st.values then Error (Duplicate_binding w)
  else Ok { st with values = Wires.add w v st.values }

let fresh st v =
  if st.next >= limit then Error Wire_count
  else Ok ({ st with next = st.next + 1;
                     values = Wires.add st.next v st.values }, st.next)

let value st w =
  let* () = valid st w in
  Wires.find_opt w st.values |> Option.to_result ~none:(Missing_binding w)

let blank = { ql = Fp.zero; qr = Fp.zero; qo = Fp.zero; qm = Fp.zero;
              qc = Fp.zero; a = 0; b = 0; c = 0; lookup = 0 }
let add_row st r =
  let* () = valid st r.a in
  let* () = valid st r.b in
  let* () = valid st r.c in
  if r.lookup <> 0 then Error (Lookup_tag r.lookup)
  else Ok { st with rev_rows = r :: st.rev_rows }

let mul_into st ~a ~b ~c =
  add_row st { blank with qm = Fp.one; qo = Fp.neg Fp.one; a; b; c }
let mul st a b =
  let* av = value st a in
  let* bv = value st b in
  let* st, c = fresh st (Fp.mul av bv) in
  let* st = mul_into st ~a ~b ~c in
  Ok (st, c)

let define st ~ca ~a ~cb ~b ~k0 ~c =
  add_row st { blank with ql = ca; qr = cb; qc = k0;
                         qo = Fp.neg Fp.one; a; b; c }
let scaled st co w =
  let* () = valid st w in
  if Fp.equal co Fp.zero then Ok Fp.zero
  else Result.map (Fp.mul co) (value st w)
let lin st ~ca ~a ~cb ~b ~k0 =
  let* av = scaled st ca a in
  let* bv = scaled st cb b in
  let* st, c = fresh st (Fp.add (Fp.add av bv) k0) in
  let* st = define st ~ca ~a ~cb ~b ~k0 ~c in
  Ok (st, c)

let assert_bit st w =
  add_row st { blank with qm = Fp.one; ql = Fp.neg Fp.one; a = w; b = w }
let assert_one st w =
  add_row st { blank with ql = Fp.one; qc = Fp.neg Fp.one; a = w }
let select st ~bit ~yes ~no =
  let* st = assert_bit st bit in
  let* st, d = lin st ~ca:Fp.one ~a:yes ~cb:(Fp.neg Fp.one) ~b:no ~k0:Fp.zero in
  let* st, m = mul st bit d in
  lin st ~ca:Fp.one ~a:m ~cb:Fp.one ~b:no ~k0:Fp.zero

(* a*i = 1-z, a*z = 0, z*i = 0 uniquely specify the total inverse.
   They also constrain z to the zero indicator, without witness branching
   in the shape or number of rows. *)
let inverse_zero st a =
  let* av = value st a in
  let* st, i = fresh st (Fp.inv av) in
  let* st, z = fresh st (if Fp.equal av Fp.zero then Fp.one else Fp.zero) in
  let* st = add_row st { blank with qm = Fp.one; qo = Fp.one;
                                   qc = Fp.neg Fp.one; a; b = i; c = z } in
  let* st = add_row st { blank with qm = Fp.one; a; b = z } in
  let* st = add_row st { blank with qm = Fp.one; a = z; b = i } in
  Ok (st, i, z)
let inv st a =
  let* st, i, _z = inverse_zero st a in
  Ok (st, i)
let equal st a b =
  let* st, d = lin st ~ca:Fp.one ~a ~cb:(Fp.neg Fp.one) ~b ~k0:Fp.zero in
  let* st, _i, z = inverse_zero st d in
  Ok (st, z)

let satisfied st r =
  let* a = value st r.a in
  let* b = value st r.b in
  let* c = value st r.c in
  Ok (Fp.equal Fp.zero (Fp.add r.qc (Fp.add (Fp.mul r.qm (Fp.mul a b))
      (Fp.add (Fp.mul r.ql a) (Fp.add (Fp.mul r.qr b) (Fp.mul r.qo c))))))

let finish st =
  let bindings = Wires.bindings st.values in
  let* next = List.fold_left (fun acc (w, _v) ->
      let* expected = acc in
      if w = expected then Ok (expected + 1) else Error (Missing_binding expected))
      (Ok 0) bindings in
  if next <> st.next then Error (Missing_binding next) else
  let rows = List.rev st.rev_rows in
  let* _count = List.fold_left (fun acc r ->
      let* i = acc in
      let* ok = satisfied st r in
      if ok then Ok (i + 1) else Error (Unsatisfied_row i)) (Ok 0) rows in
  Ok { n_pub_out = st.out; n_pub_in = st.input; n_priv = st.priv;
       n_wires = st.next; rows; witness = List.map snd bindings }
