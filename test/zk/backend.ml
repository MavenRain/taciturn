open Taciturn_zk
let ( let* ) = Result.bind
let is_error expected r = Result.fold ~ok:(fun _value -> false)
    ~error:(fun actual -> String.equal expected (Rows.error_string actual)) r
let accepts r = Result.is_ok r
let state () = Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:1
let finish_with op =
  let* st = state () in
  let* st = Rows.bind st 1 Fp.one in
  let* st = Rows.bind st 2 Fp.one in
  let* st = op st in
  Rows.finish st
let lowered r check = Result.fold ~error:(fun _e -> false)
    ~ok:(fun c -> check (Lower.compile c)) r
let canonical (lc : Lower.lc) =
  let good, _last = List.fold_left (fun (good, last) (w, v) ->
      (good && w > last && not (Fp.equal v Fp.zero), w)) (true, -1) lc in
  good

let tests = [
  "empty-decimal", Option.is_none (Fp.of_decimal "");
  "signed-decimal", Option.is_none (Fp.of_decimal "-1");
  "plus-decimal", Option.is_none (Fp.of_decimal "+1");
  "whitespace-decimal", Option.is_none (Fp.of_decimal " 1");
  "hex-decimal", Option.is_none (Fp.of_decimal "0x10");
  "decimal-width", Option.is_none (Fp.of_decimal (String.make 78 '0'));
  "prime-rejected", Option.is_none (Fp.of_decimal
      "21888242871839275222246405745257275088548364400416034343698204186575808495617");
  "signed-normalization", Fp.equal (Fp.of_int (-1)) (Fp.neg Fp.one);
  "minimum-int", Fp.equal (Fp.add (Fp.of_int min_int) (Fp.of_int max_int)) (Fp.neg Fp.one);
  "u32-negative", String.equal (Binary.u32 (-1)) "\255\255\255\255";
  "u32-wraps", String.equal (Binary.u32 0x100000005) (Binary.u32 5);
  "inverse-zero", Fp.equal (Fp.inv Fp.zero) Fp.zero;
  "counts-zero-output", is_error "counts" (Rows.init ~n_pub_out:0 ~n_pub_in:0 ~n_priv:0);
  "counts-overflow", is_error "counts" (Rows.init ~n_pub_out:max_int ~n_pub_in:1 ~n_priv:1);
  "counts-negative", is_error "counts" (Rows.init ~n_pub_out:1 ~n_pub_in:(-1) ~n_priv:0);
  "counts-private-overflow", is_error "counts" (Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:max_int);
  "wire-overflow", is_error "wire-count"
      (let* st = Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:0xfffffffd in
       Rows.fresh st Fp.zero);
  "constant-binding", is_error "duplicate-binding:0"
      (let* st = state () in Rows.bind st 0 Fp.zero);
  "duplicate-binding", is_error "duplicate-binding:1"
      (let* st = state () in let* st = Rows.bind st 1 Fp.one in Rows.bind st 1 Fp.one);
  "negative-wire", is_error "invalid-wire:-1"
      (let* st = state () in Rows.bind st (-1) Fp.one);
  "out-of-range-wire", is_error "invalid-wire:3"
      (let* st = state () in Rows.bind st 3 Fp.one);
  "missing-operand", is_error "missing-binding:2"
      (let* st = state () in Rows.mul st 0 2);
  "missing-interface", is_error "missing-binding:1"
      (let* st = state () in Rows.finish st);
  "zero-selector-wire", is_error "invalid-wire:3"
      (let* st = state () in Rows.lin st ~ca:Fp.zero ~a:3 ~cb:Fp.zero ~b:0 ~k0:Fp.zero);
  "raw-invalid-wire", is_error "invalid-wire:3"
      (let* st = state () in Rows.add_row st { Rows.blank with c = 3 });
  "lookup", is_error "lookup-tag:1"
      (let* st = state () in Rows.add_row st { Rows.blank with lookup = 1 });
  "unsatisfied-row", is_error "unsatisfied-row:0"
      (finish_with (fun st -> Rows.add_row st { Rows.blank with qc = Fp.one }));
  "assert-one", accepts (finish_with (fun st -> Rows.assert_one st 1));
  "assert-bit", accepts (finish_with (fun st -> Rows.assert_bit st 2));
  "select-rejects-two", is_error "unsatisfied-row:0"
      (Circuits.select (Fp.of_int 2) (Fp.of_int 8) (Fp.of_int 3));
  "select-rejects-two-equal-branches", is_error "unsatisfied-row:0"
      (Circuits.select (Fp.of_int 2) Fp.one Fp.one);
  "mul-count", lowered (Circuits.mul (Fp.of_int 3) (Fp.of_int 5))
      (fun c -> c.n_wires = 4 && List.length c.constraints = 1);
  "mimc-count", lowered (Circuits.mimc3 (Fp.of_int 3) (Fp.of_int 5))
      (fun c -> c.n_wires = 15 && List.length c.constraints = 12);
  "interface-retained", lowered (Circuits.interface ())
      (fun c -> c.n_wires = 4 && c.n_pub_in = 1 && c.n_priv = 1
                && List.length c.constraints = 1);
  "repeated-definition", lowered (Circuits.repeated ())
      (fun c -> c.n_wires = 3 && List.length c.constraints = 2);
  "cycle-terminates", lowered (Circuits.cycle ())
      (fun c -> List.length c.constraints = 1);
  "canonical-terms", lowered (Circuits.mimc3 (Fp.of_int 9) (Fp.of_int 2))
      (fun c -> List.for_all (fun (k : Lower.constraint_) ->
           canonical k.a && canonical k.b && canonical k.c) c.constraints);
]

let () =
  let failures = List.filter (fun (_name, ok) -> not ok) tests in
  List.iter (fun (name, _ok) -> Printf.eprintf "BACKEND FAIL %s\n" name) failures;
  Printf.printf "BACKEND %d/%d\n" (List.length tests - List.length failures) (List.length tests);
  if failures = [] then () else exit 1
