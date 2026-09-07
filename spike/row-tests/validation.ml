let checked result =
  Result.fold ~ok:Fun.id ~error:(fun error ->
      Printf.eprintf "ROW-VALIDATE FAIL unexpected %s\n" (Row.error_string error);
      exit 1) result

let expect name expected result =
  Result.fold
    ~ok:(fun _ -> Printf.eprintf "ROW-VALIDATE FAIL %s accepted\n" name; exit 1)
    ~error:(fun error ->
      if error = expected then Printf.printf "ROW-VALIDATE PASS %s\n" name
      else (Printf.eprintf "ROW-VALIDATE FAIL %s expected=%s got=%s\n"
          name (Row.error_string expected) (Row.error_string error); exit 1)) result

let base () =
  Row.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:0
  |> fun st -> Row.bind st 1 Fp.zero

let changed_row c row = { c with Row.crows = [ row ] }

let suite () =
  let st = base () in
  let c = checked (Row.finish st) in
  let raw name error circuit = expect name error (Lower.lower circuit) in
  let state name error builder = expect name error (Row.finish builder) in
  state "missing-output" (Row.Missing_binding 1)
    (Row.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:0);
  state "missing-interior" (Row.Missing_binding 1)
    { st with next_wire = 3; values = [ (0, Fp.one); (2, Fp.zero) ] };
  state "duplicate-same-value" (Row.Duplicate_binding 1) (Row.bind st 1 Fp.zero);
  state "rebind-wire-zero" (Row.Duplicate_binding 0) (Row.bind st 0 Fp.one);
  state "changed-wire-zero" Row.Wire_zero
    { st with values = [ (0, Fp.zero); (1, Fp.zero) ] };
  state "missing-wire-zero" (Row.Missing_binding 0)
    { st with values = [ (1, Fp.zero) ] };
  state "negative-binding" (Row.Invalid_wire (-1)) (Row.bind st (-1) Fp.zero);
  state "unallocated-binding" (Row.Invalid_wire 2) (Row.bind st 2 Fp.zero);
  state "negative-private-count" Row.Counts { st with n_priv = -1 };
  state "wrapped-interface-count" Row.Counts
    (Row.init ~n_pub_out:max_int ~n_pub_in:max_int ~n_priv:2);
  state "huge-state-wire-count" Row.Wire_count { st with next_wire = max_int };
  state "row-lookup-before-finish" (Row.Lookup_tag 1)
    (Row.add_row st { Row.blank with lookup = 1 });
  state "row-wire-out-of-range" (Row.Invalid_wire 9) (Row.mul_into st ~a:9 ~b:0 ~c:1);
  let missing = Row.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:0 in
  let multiplied, _ = Row.mul missing 1 0 in
  state "mul-read-before-bind" (Row.Missing_binding 1) (Row.bind multiplied 1 Fp.one);
  let linear, _ = Row.lin missing ~ca:Fp.one ~a:1 ~cb:Fp.zero ~b:0 ~k0:Fp.zero in
  state "lin-read-before-bind" (Row.Missing_binding 1) (Row.bind linear 1 Fp.one);
  let multiplied_again, _ = Row.mul (Row.bind multiplied 1 Fp.one) 1 0 in
  state "missing-read-error-persists" (Row.Missing_binding 1) multiplied_again;
  state "lin-operand-negative" (Row.Invalid_wire (-1))
    (fst (Row.lin (base ()) ~ca:Fp.one ~a:(-1) ~cb:Fp.one ~b:0 ~k0:Fp.zero));
  state "mul-operand-unallocated" (Row.Invalid_wire 2) (fst (Row.mul (base ()) 2 0));
  raw "zero-wire-count" Row.Wire_count { c with n_wires = 0 };
  raw "negative-wire-count" Row.Wire_count { c with n_wires = -1 };
  raw "wire-count-above-u32" Row.Wire_count { c with n_wires = 0x100000000 };
  raw "no-public-output" Row.Counts { c with c_pub_out = 0 };
  raw "negative-public-output" Row.Counts { c with c_pub_out = -1 };
  raw "negative-public-input" Row.Counts { c with c_pub_in = -1 };
  raw "negative-private-input" Row.Counts { c with c_priv = -1 };
  raw "public-output-overruns" Row.Counts { c with c_pub_out = 2 };
  raw "public-input-overruns" Row.Counts { c with c_pub_in = 1 };
  raw "private-input-overruns" Row.Counts { c with c_priv = 1 };
  raw "raw-wrapped-counts" Row.Counts
    { c with n_wires = 1; c_pub_out = max_int; c_pub_in = max_int; c_priv = 2;
             witness = [ Fp.one ] };
  raw "short-witness" Row.Witness_length { c with witness = [ Fp.one ] };
  raw "long-witness" Row.Witness_length { c with witness = [ Fp.one; Fp.zero; Fp.zero ] };
  raw "raw-wire-zero" Row.Wire_zero { c with witness = [ Fp.zero; Fp.zero ] };
  List.iter (fun (name, row, wire) -> raw name (Row.Invalid_wire wire) (changed_row c row))
    [ ("negative-a", { Row.blank with a = -1 }, -1);
      ("negative-b", { Row.blank with b = -1 }, -1);
      ("negative-c", { Row.blank with c = -1 }, -1);
      ("upper-a", { Row.blank with a = 2 }, 2);
      ("upper-b", { Row.blank with b = 2 }, 2);
      ("upper-c", { Row.blank with c = 2 }, 2) ];
  List.iter (fun tag -> raw (Printf.sprintf "unsupported-lookup-%d" tag)
      (Row.Lookup_tag tag) (changed_row c { Row.blank with lookup = tag })) [ -1; 1; max_int ];
  let all_blocks = Row.init ~n_pub_out:1 ~n_pub_in:1 ~n_priv:1 in
  let all_blocks = List.fold_left (fun s w -> Row.bind s w Fp.zero) all_blocks [ 3; 1; 2 ] in
  let reordered = checked (Row.finish all_blocks) in
  if reordered.n_wires <> 4 || not (List.equal Fp.equal reordered.witness
      [ Fp.one; Fp.zero; Fp.zero; Fp.zero ]) then
    (Printf.eprintf "ROW-VALIDATE FAIL reordered-bindings n_wires=%d\n"
       reordered.n_wires; exit 1);
  ignore (checked (Lower.lower reordered));
  let forward = Row.add_row (Row.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:0)
      { Row.blank with ql = Fp.one; a = 1 } in
  ignore (checked (Lower.lower (checked (Row.finish (Row.bind forward 1 Fp.zero)))));
  let late = Row.init ~n_pub_out:1 ~n_pub_in:1 ~n_priv:1 in
  let late = List.fold_left (fun s w -> Row.bind s w Fp.zero) late [ 2; 3 ] in
  let late, _ = Row.lin late ~ca:Fp.one ~a:2 ~cb:Fp.zero ~b:1 ~k0:Fp.zero in
  ignore (checked (Row.finish (Row.bind late 1 Fp.zero)));
  List.iter (fun (label, build, expected) ->
      let built, _ = build () in
      let circuit = checked built in
      let pruned, constraints = Lower.prune circuit (checked (Lower.lower circuit)) in
      if List.length constraints <> expected then
        (Printf.eprintf "ROW-VALIDATE FAIL %s constraints expected=%d got=%d\n"
           label expected (List.length constraints); exit 1);
      ignore (checked (Row.validate pruned)))
    [ ("mul-6-7", (fun () -> Main.build_mul (Fp.of_int 6) (Fp.of_int 7)), 1);
      ("mimc3-3-5", (fun () -> Main.build_mimc3 (Fp.of_int 3) (Fp.of_int 5)), 12);
      ("mimc3-0-0", (fun () -> Main.build_mimc3 Fp.zero Fp.zero), 12) ];
  Printf.printf "ROW-VALIDATE OK structural negatives, delayed bindings and circuit baselines\n"

let () =
  match Sys.argv with
  | [| _ |] -> suite ()
  | [| _; "missing"; out |] ->
      Main.emit "missing" out
        (Row.finish (Row.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:0)) Fp.zero
  | [| _; "lookup"; out |] ->
      let c = checked (Row.finish (base ())) in
      Main.emit "lookup" out (Ok (changed_row c { Row.blank with lookup = 1 })) Fp.zero
  | _ -> exit 2
