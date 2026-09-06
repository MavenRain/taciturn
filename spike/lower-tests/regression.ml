let accepts (cs : Lower.cst list) (values : Fp.t list) : bool =
  let wires = List.mapi (fun w v -> (w, v)) values in
  let eval terms =
    List.fold_left
      (fun total (w, coefficient) ->
        Option.bind total (fun acc ->
            Option.map (fun value -> Fp.add acc (Fp.mul coefficient value))
              (List.assoc_opt w wires)))
      (Some Fp.zero) terms
  in
  List.for_all
    (fun (c : Lower.cst) ->
      match (eval c.ca, eval c.cb, eval c.cc) with
      | (Some a, Some b, Some rhs) -> Fp.equal (Fp.mul a b) rhs
      | (None, _, _) | (_, None, _) | (_, _, None) -> false)
    cs

let check name st wire forged =
  let original = Row.finish st in
  let c, cs = Lower.prune original (Lower.lower original) in
  let bad = List.mapi
      (fun w value -> if w = wire then Fp.of_int forged else value) c.witness in
  if accepts cs c.witness && not (accepts cs bad) then
    Printf.printf "LOWER PASS %s\n" name
  else (Printf.eprintf "LOWER FAIL %s\n" name; exit 1)

let define st a b c =
  Row.define st ~ca:Fp.one ~a ~cb:Fp.one ~b ~k0:Fp.zero ~c

let base n_pub_in =
  let st = Row.init ~n_pub_out:1 ~n_pub_in ~n_priv:(2 - n_pub_in) in
  let st = Row.bind st 1 (Fp.of_int 13) in
  let st = Row.bind st 2 (Fp.of_int 6) in
  Row.bind st 3 (Fp.of_int 7)

let () =
  let st = define (base 0) 2 3 1 in
  check "public-output" st 1 99;
  let st = Row.define (base 1) ~ca:Fp.one ~a:1 ~cb:(Fp.neg Fp.one)
      ~b:3 ~k0:Fp.zero ~c:2 in
  check "public-input" st 2 99;
  check "private-input" (define (base 0) 2 3 1) 2 99;
  let st, intermediate = Row.lin (base 0) ~ca:Fp.one ~a:2 ~cb:Fp.one
      ~b:3 ~k0:Fp.zero in
  let repeated = Row.define st ~ca:Fp.one ~a:1 ~cb:Fp.zero ~b:0
      ~k0:Fp.zero ~c:intermediate in
  check "repeated-definition" repeated 1 99;
  let st = Row.define st ~ca:Fp.one ~a:intermediate ~cb:Fp.zero ~b:0
      ~k0:Fp.zero ~c:1 in
  check "internal-chain-to-output" st 1 99;
  let st, internal = Row.fresh (base 0) (Fp.of_int 5) in
  let st = Row.define st ~ca:Fp.one ~a:internal ~cb:Fp.one ~b:1
      ~k0:(Fp.neg (Fp.of_int 13)) ~c:internal in
  check "self-dependency" st 1 99;
  let st, a = Row.fresh (base 0) (Fp.of_int 5) in
  let st, b = Row.fresh st (Fp.of_int 5) in
  let st = Row.define st ~ca:Fp.one ~a:b ~cb:Fp.zero ~b:0 ~k0:Fp.zero ~c:a in
  let st = Row.define st ~ca:Fp.one ~a ~cb:Fp.one ~b:1
      ~k0:(Fp.neg (Fp.of_int 13)) ~c:b in
  check "cyclic-definitions" st 1 99;
  let st = Row.add_row (base 0)
      { Row.blank with ql = Fp.of_int 2; a = 1; qc = Fp.neg (Fp.of_int 26) } in
  check "general-linear-equation" st 1 99
