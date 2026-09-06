(* row.ml.  The row IR of proposal 3 section 5.  One row is the gate
   ql*a + qr*b + qo*c + qm*a*b + qc = 0 over five selector constants and
   three wire indices, plus a lookup tag that stays 0 at M0.  The builder
   state records the witness value beside every allocation, so one pass
   yields the rows and the witness together (proposal 3 section 6). *)

(* Wire 0 holds the constant one. *)
type wire = int

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

let blank : row =
  {
    ql = Fp.zero;
    qr = Fp.zero;
    qo = Fp.zero;
    qm = Fp.zero;
    qc = Fp.zero;
    a = 0;
    b = 0;
    c = 0;
    lookup = 0;
  }

let add_row (st : state) (r : row) : state = { st with rows = r :: st.rows }

(* c := a * b over a wire that already has its number. *)
let mul_into (st : state) ~(a : wire) ~(b : wire) ~(c : wire) : state =
  add_row st { blank with qm = Fp.one; qo = Fp.neg Fp.one; a; b; c }

(* c := a * b over a new wire, whose value is the product. *)
let mul (st : state) (a : wire) (b : wire) : state * wire =
  let (st1, c) = fresh st (Fp.mul (value_of st a) (value_of st b)) in
  (mul_into st1 ~a ~b ~c, c)

(* c := ca*a + cb*b + k0 over a new wire.  L1 folds this row away. *)
let lin (st : state) ~(ca : Fp.t) ~(a : wire) ~(cb : Fp.t) ~(b : wire)
    ~(k0 : Fp.t) : state * wire =
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

let finish (st : state) : circuit =
  {
    c_pub_out = st.n_pub_out;
    c_pub_in = st.n_pub_in;
    c_priv = st.n_priv;
    n_wires = st.next_wire;
    crows = List.rev st.rows;
    witness = List.init st.next_wire (fun w -> value_of st w);
  }
