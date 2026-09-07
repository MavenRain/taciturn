(* row.ml.  The row IR of proposal 3 section 5.  One row is the gate
   ql*a + qr*b + qo*c + qm*a*b + qc = 0 over five selector constants and
   three wire indices, plus a lookup tag that stays 0 at M0.  The builder
   state records the witness value beside every allocation, so one pass
   yields the rows and the witness together (proposal 3 section 6). *)

(* Wire 0 holds the constant one. *)
type wire = int

type error =
  | Counts | Wire_count | Wire_zero | Witness_length
  | Missing_binding of wire | Duplicate_binding of wire | Invalid_wire of wire
  | Lookup_tag of int

let error_string = function
  | Counts -> "counts"
  | Wire_count -> "wire-count"
  | Wire_zero -> "wire-zero"
  | Witness_length -> "witness-length"
  | Missing_binding w -> Printf.sprintf "missing-binding:%d" w
  | Duplicate_binding w -> Printf.sprintf "duplicate-binding:%d" w
  | Invalid_wire w -> Printf.sprintf "invalid-wire:%d" w
  | Lookup_tag tag -> Printf.sprintf "lookup-tag:%d" tag

let ( let* ) = Result.bind

type row = {
  ql : Fp.t;
  qr : Fp.t;
  qo : Fp.t;
  qm : Fp.t;
  qc : Fp.t;
  a : wire;
  b : wire;
  c : wire;
  lookup : int;
}

type state = {
  next_wire : wire;
  rows : row list;              (* newest first *)
  values : (wire * Fp.t) list;  (* one entry per numbered wire *)
  n_pub_out : int;
  n_pub_in : int;
  n_priv : int;
  problem : error option;
}

type circuit = {
  c_pub_out : int;
  c_pub_in : int;
  c_priv : int;
  n_wires : int;
  crows : row list;     (* oldest first *)
  witness : Fp.t list;  (* wire 0 first *)
}

(* snarkjs reads the wires in one order: wire 0, the public outputs, the
   public inputs, the private inputs, then the internal wires.  The three
   input blocks take their numbers here, at the start, and their values
   arrive through [bind], which lets a public output be numbered early and
   valued late. *)
let init ~(n_pub_out : int) ~(n_pub_in : int) ~(n_priv : int) : state =
  {
    next_wire = 1 + n_pub_out + n_pub_in + n_priv;
    rows = [];
    values = [ (0, Fp.one) ];
    n_pub_out;
    n_pub_in;
    n_priv;
    problem = None;
  }

let bind (st : state) (w : wire) (v : Fp.t) : state =
  { st with values = (w, v) :: st.values }

let fresh (st : state) (v : Fp.t) : state * wire =
  ( { st with
      next_wire = st.next_wire + 1;
      values = (st.next_wire, v) :: st.values },
    st.next_wire )

let value_of (st : state) (w : wire) : Fp.t =
  Option.value (List.assoc_opt w st.values) ~default:Fp.zero

(* A missing operand stays an error even when its binding arrives later. *)
let require (st : state) (ws : wire list) : state =
  let fault w =
    if w < 0 || w >= st.next_wire then Some (Invalid_wire w)
    else if List.mem_assoc w st.values then None else Some (Missing_binding w)
  in
  { st with problem = Option.fold ~some:(fun e -> Some e)
      ~none:(List.find_map fault ws) st.problem }

let blank : row =
  {
    ql = Fp.zero;
    qr = Fp.zero;
    qo = Fp.zero;
    qm = Fp.zero; qc = Fp.zero;
    a = 0; b = 0; c = 0; lookup = 0;
  }

let add_row (st : state) (r : row) : state = { st with rows = r :: st.rows }

(* c := a * b over a wire that already has its number. *)
let mul_into (st : state) ~(a : wire) ~(b : wire) ~(c : wire) : state =
  add_row st { blank with qm = Fp.one; qo = Fp.neg Fp.one; a; b; c }

(* c := a * b over a new wire, whose value is the product. *)
let mul (st : state) (a : wire) (b : wire) : state * wire =
  let st = require st [ a; b ] in
  let (st1, c) = fresh st (Fp.mul (value_of st a) (value_of st b)) in
  (mul_into st1 ~a ~b ~c, c)

(* c := ca*a + cb*b + k0 over a new wire.  L1 folds this row away. *)
let lin (st : state) ~(ca : Fp.t) ~(a : wire) ~(cb : Fp.t) ~(b : wire)
    ~(k0 : Fp.t) : state * wire =
  let st = require st (List.filter_map (fun (co, w) ->
      if Fp.equal co Fp.zero then None else Some w) [ (ca, a); (cb, b) ]) in
  let v =
    Fp.add (Fp.add (Fp.mul ca (value_of st a)) (Fp.mul cb (value_of st b))) k0
  in
  let (st1, c) = fresh st v in
  ( add_row st1
      { blank with ql = ca; qr = cb; qc = k0; qo = Fp.neg Fp.one; a; b; c },
    c )

(* The same linear row over a wire that already exists, so a wire produced
   by a product row can be stated out of a public one.  L1 folds it into
   the position that holds the wire, the c position included. *)
let define (st : state) ~(ca : Fp.t) ~(a : wire) ~(cb : Fp.t) ~(b : wire)
    ~(k0 : Fp.t) ~(c : wire) : state =
  add_row st
    { blank with ql = ca; qr = cb; qc = k0; qo = Fp.neg Fp.one; a; b; c }

(* Bounds use subtraction, so malformed counts cannot overflow a sum. *)
let counts n out input priv =
  if n < 1 || Int64.compare (Int64.of_int n) 0xffffffffL > 0 then Error Wire_count
  else if out < 1 || out > n - 1 || input < 0 || input > n - 1 - out
          || priv < 0 || priv > n - 1 - out - input then Error Counts
  else Ok ()

let wires n ws =
  Option.fold ~none:(Ok ()) ~some:(fun w -> Error (Invalid_wire w))
    (List.find_opt (fun w -> w < 0 || w >= n) ws)

let validate (c : circuit) : (unit, error) result =
  let* () = counts c.n_wires c.c_pub_out c.c_pub_in c.c_priv in
  if List.length c.witness <> c.n_wires then Error Witness_length
  else if not (Option.fold ~none:false ~some:(Fp.equal Fp.one)
                 (List.find_opt (fun _ -> true) c.witness)) then Error Wire_zero
  else List.fold_left (fun checked (r : row) ->
      let* () = checked in
      let* () = wires c.n_wires [ r.a; r.b; r.c ] in
      if r.lookup = 0 then Ok () else Error (Lookup_tag r.lookup)) (Ok ()) c.crows

let finish (st : state) : (circuit, error) result =
  let* () = Option.fold ~none:(Ok ()) ~some:(fun e -> Error e) st.problem in
  let* () = counts st.next_wire st.n_pub_out st.n_pub_in st.n_priv in
  let bindings = List.sort (fun (a, _) (b, _) -> Int.compare a b) st.values in
  let* () = wires st.next_wire (List.map fst bindings) in
  let* next = List.fold_left (fun next (w, _) ->
      let* expected = next in
      if w < expected then Error (Duplicate_binding w)
      else if w > expected then Error (Missing_binding expected)
      else Ok (expected + 1)) (Ok 0) bindings in
  if next <> st.next_wire then Error (Missing_binding next) else
  let c = {
    c_pub_out = st.n_pub_out;
    c_pub_in = st.n_pub_in;
    c_priv = st.n_priv;
    n_wires = st.next_wire;
    crows = List.rev st.rows;
    witness = List.map snd bindings;
  } in
  let* () = validate c in
  Ok c
