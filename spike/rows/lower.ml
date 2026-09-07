(* lower.ml.  L1 of proposal 3 section 5: rows to R1CS constraints.
   A row with qm nonzero becomes one constraint A * B = C, with
   A = { (a, qm) }, B = { (b, 1) } and
   C = { (a, -ql), (b, -qr), (c, -qo), (0, -qc) }.
   A linear definition of an internal wire can fold into every use of
   that wire.  Interface wires remain explicit, and residual linear
   equations become constraints.  Wire 0 carries the constant term. *)

open Row

type term = int * Fp.t
type lc = term list
type cst = { ca : lc; cb : lc; cc : lc }

(* One entry per wire, no zero coefficient, ascending by wire id. *)
let norm (ts : term list) : lc =
  let merged =
    List.fold_left
      (fun acc (w, v) ->
        let (same, rest) = List.partition (fun (w2, _) -> w2 = w) acc in
        (w, List.fold_left (fun s (_, v2) -> Fp.add s v2) v same) :: rest)
      [] ts
  in
  List.sort
    (fun (w1, _) (w2, _) -> Int.compare w1 w2)
    (List.filter (fun (_, v) -> not (Fp.equal v Fp.zero)) merged)

(* Puts the known linear combinations in the place of the wires that hold
   them, scaling each one by the coefficient it stood under. *)
let subst (m : (int * lc) list) (ts : term list) : term list =
  List.concat_map
    (fun (w, v) ->
      Option.fold
        ~none:[ (w, v) ]
        ~some:(List.map (fun (w2, v2) -> (w2, Fp.mul v v2)))
        (List.assoc_opt w m))
    ts

let is_linear (r : row) : bool = Fp.equal r.qm Fp.zero

(* Only eliminate internal wires with coefficient -1.  Resolve each new
   definition in both directions, rejecting self dependencies and keeping
   repeated definitions as residual equations instead of overwriting them. *)
let defs (n_iface : int) (rows : row list) : (int * lc) list =
  List.fold_left
    (fun m (r : row) ->
      if not (is_linear r) || r.c < n_iface
         || not (Fp.equal r.qo (Fp.neg Fp.one)) || List.mem_assoc r.c m then m
      else
        let rhs = norm (subst m [ (r.a, r.ql); (r.b, r.qr); (0, r.qc) ]) in
        if List.mem_assoc r.c rhs then m
        else
          (r.c, rhs)
          :: List.map (fun (w, l) -> (w, norm (subst [ (r.c, rhs) ] l))) m)
    [] rows

(* Every wire that stands in one of the three positions of one emitted
   constraint, ascending and without a repeat. *)
let wires_of (cs : cst list) : int list =
  List.sort_uniq Int.compare
    (List.concat_map
       (fun (k : cst) -> List.map (fun (w, _) -> w) (k.ca @ k.cb @ k.cc))
       cs)

let renumber (m : (int * int) list) (l : lc) : lc =
  List.map
    (fun (w, v) -> (Option.value (List.assoc_opt w m) ~default:w, v))
    l

(* Consume only a validated circuit and its lowered constraints.  Drop
   unused internal wires, retaining wire 0 and the interface in snarkjs order.
   Monotone renumbering preserves sorted, unique terms; erase consumed rows
   whose old ids no longer describe the pruned witness and counts. *)
let prune (c : Row.circuit) (cs : cst list) : Row.circuit * cst list =
  let n_iface = 1 + c.c_pub_out + c.c_pub_in + c.c_priv in
  let kept =
    List.sort_uniq Int.compare
      (List.init n_iface (fun w -> w) @ wires_of cs)
  in
  let m = List.mapi (fun i w -> (w, i)) kept in
  ( { c with
      n_wires = List.length kept;
      crows = [];
      witness = List.filteri (fun w _ -> List.mem w kept) c.witness },
    List.map
      (fun (k : cst) ->
        { ca = renumber m k.ca; cb = renumber m k.cb; cc = renumber m k.cc })
      cs )

let lower (c : Row.circuit) : (cst list, Row.error) result =
  let* () = Row.validate c in
  let m = defs (1 + c.c_pub_out + c.c_pub_in + c.c_priv) c.crows in
  Ok (List.filter_map
    (fun (r : row) ->
      let k =
        {
          ca = norm (subst m [ (r.a, r.qm) ]);
          cb = norm (subst m [ (r.b, Fp.one) ]);
          cc = norm (subst m
              [ (r.a, Fp.neg r.ql); (r.b, Fp.neg r.qr);
                (r.c, Fp.neg r.qo); (0, Fp.neg r.qc) ]);
        }
      in
      if is_linear r && k.cc = [] then None else Some k)
    c.crows)
