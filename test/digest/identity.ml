open Taciturn_zk
module Hash = Taciturn_zk_host.Hash
let ( let* ) = Result.bind
let require label = Result.fold ~ok:Fun.id ~error:(fun _error ->
    Printf.eprintf "DIGEST SETUP %s\n" label; exit 1)
let hex text = Option.fold ~none:(fun () ->
    Printf.eprintf "DIGEST SETUP hex\n"; exit 1) ~some:(fun h () -> h)
    (Digest.of_hex text) ()
let h0 = hex (String.make 64 '0')
let h1 = hex (String.make 64 '1')
let h2 = hex (String.make 64 '2')
let imports : Digest.imports = { zk = h0; sym = h1; pre = h2 }
let widths = [ "Field", 1; "Bit", 1; "Unit", 0 ]
let context ?(version = "taciturn-test-v1") ?(widths = widths)
    ?(imports = imports) () =
  Digest.context ~compiler_version:version ~widths ~imports
let base = require "context" (context ())
let mul x y = require "mul" (Circuits.mul (Fp.of_int x) (Fp.of_int y))
let circuit = mul 3 5
let encode c = Digest.encode base c
let changed ctx = Digest.encode (require "changed-context" ctx) circuit <> encode circuit
let diagnostic expected r = Result.fold ~ok:(fun _c -> false)
    ~error:(fun e -> Digest.error_string e = expected) r
let bare ~out ~input ~priv rows = require "bare"
    (let* st = Rows.init ~n_pub_out:out ~n_pub_in:input ~n_priv:priv in
     let* st = List.fold_left (fun acc w -> let* st = acc in Rows.bind st w Fp.zero)
         (Ok st) (List.init (out + input + priv) (fun n -> n + 1)) in
     let* st = List.fold_left (fun acc row -> let* st = acc in Rows.add_row st row)
         (Ok st) rows in
     Rows.finish st)
let bare_rows rows = bare ~out:1 ~input:0 ~priv:2 rows
let r = { Rows.blank with a = 1; b = 2; c = 3 }
let different_row row = encode (bare_rows [ r ]) <> encode (bare_rows [ row ])
let bit with_row = require "bit"
    (let* st = Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:0 in
     let* st = Rows.bind st 1 Fp.one in
     let* st = if with_row then Rows.assert_bit st 1 else Ok st in
     Rows.finish st)
let constant v = require "constant"
    (let* st = Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:0 in
     let* st = Rows.bind st 1 v in
     let* st = Rows.add_row st { Rows.blank with ql = Fp.neg Fp.one; qc = v; a = 1 } in
     Rows.finish st)
let fresh_wire = require "fresh-wire"
    (let* st = Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:0 in
     let* st = Rows.bind st 1 Fp.zero in
     let* st, _w = Rows.fresh st Fp.zero in
     Rows.finish st)
let stable build =
  let original = encode (require "stable-base" (build 0)) in
  List.for_all (fun n -> encode (require "stable-case" (build n)) = original)
    (List.init 1000 Fun.id)
let hash_is text expected = Result.fold ~error:(fun _e -> false)
    ~ok:(fun h -> Digest.to_hex h = expected) (Hash.bytes text)

let tests = [
  "hex-short", Option.is_none (Digest.of_hex (String.make 63 'a'));
  "hex-long", Option.is_none (Digest.of_hex (String.make 65 'a'));
  "hex-invalid", Option.is_none (Digest.of_hex (String.make 64 'g'));
  "hex-case", Digest.to_hex (hex (String.make 64 'A')) = String.make 64 'a';
  "version-empty", diagnostic "digest-compiler-version" (context ~version:"" ());
  "width-name-empty", diagnostic "digest-width-name" (context ~widths:[ "", 1 ] ());
  "width-negative", diagnostic "digest-width-value:Field" (context ~widths:[ "Field", -1 ] ());
  "width-overflow", diagnostic "digest-width-value:Field" (context ~widths:[ "Field", 0x100000000 ] ());
  "width-maximum", Result.is_ok (context ~widths:[ "Field", 0xffffffff ] ());
  "width-duplicate", diagnostic "digest-duplicate-width:Field"
      (context ~widths:[ "Field", 1; "Bit", 1; "Field", 2 ] ());
  "width-order", not (changed (context ~widths:(List.rev widths) ()));
  "width-value", changed (context ~widths:[ "Field", 2; "Bit", 1; "Unit", 0 ] ());
  "width-name", changed (context ~widths:[ "Other", 1; "Bit", 1; "Unit", 0 ] ());
  "zero-width-present", changed (context ~widths:[ "Field", 1; "Bit", 1 ] ());
  "compiler", changed (context ~version:"taciturn-test-v2" ());
  "zk-import", changed (context ~imports:{ imports with zk = h1 } ());
  "sym-import", changed (context ~imports:{ imports with sym = h2 } ());
  "pre-import", changed (context ~imports:{ imports with pre = h0 } ());
  "import-namespaces", changed (context ~imports:{ imports with zk = h1; sym = h0 } ());
  "public-output-count", encode (bare ~out:1 ~input:1 ~priv:1 []) <>
      encode (bare ~out:2 ~input:0 ~priv:1 []);
  "private-input-count", encode (bare ~out:1 ~input:1 ~priv:1 []) <>
      encode (bare ~out:1 ~input:0 ~priv:2 []);
  "allocated-wires", encode (bare ~out:1 ~input:0 ~priv:0 []) <>
      encode (require "extra-wire" (let* st = Rows.init ~n_pub_out:1 ~n_pub_in:0 ~n_priv:0 in
          let* st = Rows.bind st 1 Fp.zero in let* st, _w = Rows.fresh st Fp.zero in Rows.finish st));
  "selector-ql", different_row { r with ql = Fp.one };
  "selector-qr", different_row { r with qr = Fp.one };
  "selector-qo", different_row { r with qo = Fp.one };
  "selector-qm", different_row { r with qm = Fp.one };
  "selector-qc", encode (constant Fp.one) <> encode (constant (Fp.of_int 2));
  "wire-a", different_row { r with a = 2 };
  "wire-b", different_row { r with b = 3 };
  "wire-c", different_row { r with c = 1 };
  "row-order", encode (bare_rows [ r; { r with ql = Fp.one } ]) <>
      encode (bare_rows [ { r with ql = Fp.one }; r ]);
  "row-count", encode (bare_rows [ r ]) <> encode (bare_rows [ r; r ]);
  "booleanity-row", encode (bit true) <> encode (bit false);
  "pre-lowering-rows", encode (bare_rows []) <> encode (bare_rows [ r ]) &&
      R1cs.encode (Lower.compile (bare_rows [])) = R1cs.encode (Lower.compile (bare_rows [ r ]));
  "mul-witness-1000", stable (fun n -> Circuits.mul (Fp.of_int n) (Fp.of_int (n + 1)));
  "mimc-witness-1000", stable (fun n -> Circuits.mimc3 (Fp.of_int n) (Fp.of_int (n + 1)));
  "inverse-witness-1000", stable (fun n -> Circuits.inverse (Fp.of_int n));
  "equality-witness-1000", stable (fun n -> Circuits.equality (Fp.of_int n) Fp.zero);
  "select-witness-1000", stable (fun n -> Circuits.select
      (Fp.of_int (n mod 2)) (Fp.of_int n) (Fp.of_int (n + 1)));
  "sha256-empty", hash_is "" "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
  "sha256-abc", hash_is "abc" "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
  "hash-circuit", Result.fold ~error:(fun _e -> false)
      ~ok:(fun actual -> Hash.bytes (encode circuit) = Ok actual) (Hash.circuit base circuit);
  "public-output-count-isolated", encode (bare ~out:2 ~input:0 ~priv:0 []) <>
      encode fresh_wire;
  "public-input-count", encode (bare ~out:1 ~input:1 ~priv:0 []) <>
      encode fresh_wire;
  "private-input-count-isolated", encode (bare ~out:1 ~input:0 ~priv:1 []) <>
      encode fresh_wire;
  "signal-name", Hash.error_string (Hash.Process (Unix.WSIGNALED Sys.sigkill)) =
      "digest-hash-signal:kill";
]
let () =
  let failures = List.filter (fun (_name, ok) -> not ok) tests in
  List.iter (fun (name, _ok) -> Printf.eprintf "DIGEST FAIL %s\n" name) failures;
  let total = 46 in
  if List.length tests <> total then
    (Printf.eprintf "DIGEST COUNT %d\n" (List.length tests); exit 1) else ();
  Printf.printf "DIGEST %d/%d\n" (total - List.length failures) total;
  if failures = [] then () else exit 1
