(* main.ml.  The Stage 0 driver of spike (a).  Usage:
     rows.exe mul X Y OUT
     rows.exe mimc3 X K OUT
   X, Y and K are decimal.  OUT.r1cs and OUT.wtns are written and exactly
   one ROWS line is printed.  Usage errors exit 2 with ROWS-USAGE;
   invalid circuits exit 1 with ROWS-FAIL before either file is opened. *)

(* The round constants of the brief section 4.  They are spike constants,
   picked so that three builders agree on them;  they are not the
   circomlib MiMC-7 constants and no security claim rides on them. *)
let round_constants = [ 1; 2; 3 ]

let usage () =
  print_string "ROWS-USAGE\n";
  exit 2

let checked result =
  Result.fold ~ok:Fun.id ~error:(fun error ->
      Printf.eprintf "ROWS-FAIL reason=%s\n" (Row.error_string error); exit 1) result

(* L1 validates before lowering; pruning then drops unused internal wires.
   Interface slots keep their specified order even when unconstrained.
   Only the validated, pruned circuit reaches either writer. *)
let emit (name : string) (out : string) (built : (Row.circuit, Row.error) result)
    (h : Fp.t) : unit =
  let c = checked built in
  let pc, cs = Lower.prune c (checked (Lower.lower c)) in
  R1cs.write (String.concat "" [ out; ".r1cs" ]) pc cs;
  Wtns.write (String.concat "" [ out; ".wtns" ]) pc.witness;
  print_string
    (Printf.sprintf
       "ROWS %s constraints=%d wires=%d pub_out=%d pub_in=%d priv=%d out=%s\n"
       name (List.length cs) pc.n_wires pc.c_pub_out pc.c_pub_in pc.c_priv
       (Fp.to_decimal h))

(* x * y = z, with x and y private and z the public output.  Wire 1 is z,
   wire 2 is x and wire 3 is y, so the one product row lands its result on
   the public output wire itself and L1 emits one constraint. *)
let build_mul (x : Fp.t) (y : Fp.t) : (Row.circuit, Row.error) result * Fp.t =
  let z = Fp.mul x y in
  let st = Row.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:2 in
  let st = Row.bind st 1 z in
  let st = Row.bind st 2 x in
  let st = Row.bind st 3 y in
  (Row.finish (Row.mul_into st ~a:2 ~b:3 ~c:1), z)

(* MiMC-3 of the brief section 4.  Each round takes t = x_i + k + c_i on
   one linear row, then x_{i+1} = t^7 on four product rows, t2 = t * t,
   t4 = t2 * t2, t6 = t4 * t2 and t7 = t6 * t.  Three rounds give 12
   product rows. *)
let rounds (st : Row.state) (x : Row.wire) (k : Row.wire) :
    Row.state * Row.wire =
  List.fold_left
    (fun (st, xi) ci ->
      let (st, t) =
        Row.lin st ~ca:Fp.one ~a:xi ~cb:Fp.one ~b:k ~k0:(Fp.of_int ci)
      in
      let (st, t2) = Row.mul st t t in
      let (st, t4) = Row.mul st t2 t2 in
      let (st, t6) = Row.mul st t4 t2 in
      Row.mul st t6 t)
    (st, x) round_constants

(* Wire 1 is h, wire 2 is k and wire 3 is x.  The value of h is known only
   once the rounds have run, and [bind] carries it to the wire numbered at
   the start.  The closing row states h - k - x3 = 0 as a definition of
   the internal wire x3, so L1 folds it into the c position of the last
   product row and the emitted count stays at 12.  That fold leaves x3
   itself out of every constraint, as it leaves out the three t_i, and the
   pruning pass of L1 then drops those four wires from the wire count and
   from the witness. *)
let build_mimc3 (x : Fp.t) (k : Fp.t) : (Row.circuit, Row.error) result * Fp.t =
  let st = Row.init ~n_pub_out:1 ~n_pub_in:1 ~n_priv:1 in
  let st = Row.bind st 2 k in
  let st = Row.bind st 3 x in
  let (st, x3) = rounds st 3 2 in
  let h = Fp.add (Row.value_of st x3) k in
  let st = Row.bind st 1 h in
  let st =
    Row.define st ~ca:Fp.one ~a:1 ~cb:(Fp.neg Fp.one) ~b:2 ~k0:Fp.zero ~c:x3
  in
  (Row.finish st, h)

(* Two decimal arguments, or the usage line and status 2. *)
let run2 (s1 : string) (s2 : string) (go : Fp.t -> Fp.t -> unit) : unit =
  let pair =
    Option.bind (Fp.of_decimal s1) (fun v1 ->
        Option.map (fun v2 -> (v1, v2)) (Fp.of_decimal s2))
  in
  Option.iter (fun (v1, v2) -> go v1 v2) pair;
  if Option.is_none pair then usage () else ()

(* The command line arrives at a fixed shape and is read by shape, so the
   driver needs no indexing and no length arithmetic. *)
let run () =
  match Sys.argv with
  | [| _; "mul"; xs; ys; out |] ->
      run2 xs ys (fun x y ->
          let (c, z) = build_mul x y in
          emit "mul" out c z)
  | [| _; "mimc3"; xs; ks; out |] ->
      run2 xs ks (fun x k ->
          let (c, h) = build_mimc3 x k in
          emit "mimc3" out c h)
  | _ -> usage ()
