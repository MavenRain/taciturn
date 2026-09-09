(** Adapted from spike/rows/lower.ml.  Linear substitution preserves
    interface wires, repeated definitions and residual equations. *)
module Wires = Map.Make (Int)
module Used = Set.Make (Int)
type lc = (Rows.wire * Fp.t) list
type constraint_ = { a : lc; b : lc; c : lc }
type t = {
  n_pub_out : int; n_pub_in : int; n_priv : int;
  n_wires : int; constraints : constraint_ list; witness : Fp.t list;
}

let norm terms =
  let merged = List.fold_left (fun m (w, v) ->
      Wires.update w (fun previous ->
          let sum = Fp.add v (Option.value previous ~default:Fp.zero) in
          if Fp.equal sum Fp.zero then None else Some sum) m)
      Wires.empty terms in
  Wires.bindings merged

let subst definitions terms =
  List.concat_map (fun (w, v) ->
      Option.fold ~none:[ (w, v) ]
        ~some:(List.map (fun (w2, v2) -> (w2, Fp.mul v v2)))
        (Wires.find_opt w definitions)) terms |> norm

let linear (r : Rows.row) = Fp.equal r.qm Fp.zero
let definitions n_iface rows =
  List.fold_left (fun m (r : Rows.row) ->
      if not (linear r) || r.c < n_iface
         || not (Fp.equal r.qo (Fp.neg Fp.one)) || Wires.mem r.c m then m
      else
        let rhs = subst m [ (r.a, r.ql); (r.b, r.qr); (0, r.qc) ] in
        if List.mem_assoc r.c rhs then m
        else
          let replacement = Wires.singleton r.c rhs in
          Wires.add r.c rhs (Wires.map (subst replacement) m)) Wires.empty rows

let lower n_iface rows =
  let m = definitions n_iface rows in
  List.filter_map (fun (r : Rows.row) ->
      let k = {
        a = subst m [ (r.a, r.qm) ];
        b = subst m [ (r.b, Fp.one) ];
        c = subst m [ (r.a, Fp.neg r.ql); (r.b, Fp.neg r.qr);
                      (r.c, Fp.neg r.qo); (0, Fp.neg r.qc) ];
      } in
      if linear r && k.c = [] then None else Some k) rows

let compile (c : Rows.circuit) =
  let n_iface = 1 + c.n_pub_out + c.n_pub_in + c.n_priv in
  let constraints = lower n_iface c.rows in
  let used = List.fold_left (fun ws k ->
      List.fold_left (fun ws (w, _v) -> Used.add w ws) ws (k.a @ k.b @ k.c))
      Used.empty constraints in
  (* Every interface slot survives, including unused inputs.  Number all
     source wires monotonically: references to a discarded wire cannot
     occur, since the retained set includes all constraint references. *)
  let _next, mapping, witness = List.fold_left (fun (next, mapping, values) (w, v) ->
      let keep = w < n_iface || Used.mem w used in
      ( (if keep then next + 1 else next), Wires.add w next mapping,
        (if keep then v :: values else values) ))
      (0, Wires.empty, []) (List.mapi (fun w v -> (w, v)) c.witness) in
  let renumber lc = List.map (fun (w, v) ->
      (Option.value (Wires.find_opt w mapping) ~default:w, v)) lc in
  { n_pub_out = c.n_pub_out; n_pub_in = c.n_pub_in; n_priv = c.n_priv;
    n_wires = List.length witness; witness = List.rev witness;
    constraints = List.map (fun k ->
        { a = renumber k.a; b = renumber k.b; c = renumber k.c }) constraints }
