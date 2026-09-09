open Taciturn_zk
let ( let* ) = Result.bind

let mul x y =
  let* st = Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:2 in
  let* st = Rows.bind st 1 (Fp.mul x y) in
  let* st = Rows.bind st 2 x in
  let* st = Rows.bind st 3 y in
  let* st = Rows.mul_into st ~a:2 ~b:3 ~c:1 in
  Rows.finish st

let mimc3 x k =
  let* st = Rows.init ~n_pub_out:1 ~n_pub_in:1 ~n_priv:1 in
  let* st = Rows.bind st 2 k in
  let* st = Rows.bind st 3 x in
  let* st, x3 = List.fold_left (fun acc ci ->
      let* st, xi = acc in
      let* st, t = Rows.lin st ~ca:Fp.one ~a:xi ~cb:Fp.one ~b:2 ~k0:(Fp.of_int ci) in
      let* st, t2 = Rows.mul st t t in
      let* st, t4 = Rows.mul st t2 t2 in
      let* st, t6 = Rows.mul st t4 t2 in
      Rows.mul st t6 t) (Ok (st, 3)) [ 1; 2; 3 ] in
  let* v = Rows.value st x3 in
  let* st = Rows.bind st 1 (Fp.add v k) in
  let* st = Rows.define st ~ca:Fp.one ~a:1 ~cb:(Fp.neg Fp.one) ~b:2
      ~k0:Fp.zero ~c:x3 in
  Rows.finish st

let publish st wire =
  let* v = Rows.value st wire in
  let* st = Rows.bind st 1 v in
  let* st = Rows.define st ~ca:Fp.one ~a:1 ~cb:Fp.zero ~b:0 ~k0:Fp.zero ~c:wire in
  Rows.finish st

let inverse x =
  let* st = Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:1 in
  let* st = Rows.bind st 2 x in
  let* st, wire = Rows.inv st 2 in
  publish st wire

let equality x y =
  let* st = Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:2 in
  let* st = Rows.bind st 2 x in
  let* st = Rows.bind st 3 y in
  let* st, wire = Rows.equal st 2 3 in
  publish st wire

let select bit x y =
  let* st = Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:3 in
  let* st = Rows.bind st 2 bit in
  let* st = Rows.bind st 3 x in
  let* st = Rows.bind st 4 y in
  let* st, wire = Rows.select st ~bit:2 ~yes:3 ~no:4 in
  publish st wire

(* A repeated internal definition adds a residual equation on the input.
   Dropping the second definition would admit arbitrary private inputs. *)
let repeated () =
  let* st = Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:1 in
  let* st = Rows.bind st 2 (Fp.of_int 3) in
  let* st, w = Rows.lin st ~ca:Fp.one ~a:2 ~cb:Fp.zero ~b:0 ~k0:Fp.zero in
  let* st = Rows.define st ~ca:Fp.zero ~a:0 ~cb:Fp.zero ~b:0
      ~k0:(Fp.of_int 3) ~c:w in
  publish st w

(* The two definitions form a cycle.  Substitution must leave the
   remaining relation explicit and terminate. *)
let cycle () =
  let* st = Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:0 in
  let* st, a = Rows.fresh st (Fp.of_int 3) in
  let* st, b = Rows.fresh st (Fp.of_int 2) in
  let* st = Rows.define st ~ca:Fp.one ~a:b ~cb:Fp.zero ~b:0 ~k0:Fp.one ~c:a in
  let* st = Rows.define st ~ca:Fp.one ~a ~cb:Fp.zero ~b:0
      ~k0:(Fp.neg Fp.one) ~c:b in
  let* st = Rows.mul_into st ~a:b ~b:b ~c:1 in
  let* st = Rows.bind st 1 (Fp.of_int 4) in
  Rows.finish st

let interface () =
  let* st = Rows.init ~n_pub_out:1 ~n_pub_in:1 ~n_priv:1 in
  let* st = Rows.bind st 1 (Fp.of_int 9) in
  let* st = Rows.bind st 2 (Fp.of_int 9) in
  let* st = Rows.bind st 3 (Fp.of_int 42) in
  let* st, _unused = Rows.fresh st (Fp.of_int 7) in
  let* st = Rows.define st ~ca:Fp.one ~a:2 ~cb:Fp.zero ~b:0 ~k0:Fp.zero ~c:1 in
  Rows.finish st
