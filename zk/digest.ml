(** Pure encoding; SHA-256 runs at the host boundary. *)
let ( let* ) = Result.bind
type sha256 = string
let of_hex s =
  if String.length s = 64 && String.for_all (function
      | '0' .. '9' | 'a' .. 'f' | 'A' .. 'F' -> true
      | _char -> false) s
  then Some (String.lowercase_ascii s) else None
let to_hex h = h

type imports = { zk : sha256; sym : sha256; pre : sha256 }
type error =
  | Compiler_version
  | Width_name
  | Width_value of string
  | Duplicate_width of string
let error_string = function
  | Compiler_version -> "digest-compiler-version"
  | Width_name -> "digest-width-name"
  | Width_value name -> "digest-width-value:" ^ name
  | Duplicate_width name -> "digest-duplicate-width:" ^ name
type context = {
  compiler_version : string; widths : (string * int) list; imports : imports;
}
let context ~compiler_version ~widths ~imports =
  if compiler_version = "" then Error Compiler_version else
  let widths = List.sort (fun (a, _x) (b, _y) -> String.compare a b) widths in
  let* _last = List.fold_left (fun acc (name, width) ->
      let* last = acc in
      match () with
      | () when name = "" -> Error Width_name
      | () when width < 0 || width > 0xffffffff -> Error (Width_value name)
      | () when last = Some name -> Error (Duplicate_width name)
      | () -> Ok (Some name)) (Ok None) widths in
  Ok { compiler_version; widths; imports }

let framed s = Binary.u64 (String.length s) ^ s
let row (r : Rows.row) = String.concat ""
    (List.map Fp.to_bytes_le [ r.ql; r.qr; r.qo; r.qm; r.qc ] @
     List.map Binary.u32 [ r.a; r.b; r.c; r.lookup ])
let encode context (c : Rows.circuit) =
  let imports = context.imports in
  let rows = c.rows in
  String.concat "" [
    "taciturn-circuit\000"; Binary.u32 1; framed "sha256";
    framed "plonk-rows-bn254-v1"; Fp.prime_bytes_le;
    framed context.compiler_version;
    framed "zk"; to_hex imports.zk; framed "sym"; to_hex imports.sym;
    framed "pre"; to_hex imports.pre;
    Binary.u64 (List.length context.widths);
    String.concat "" (List.map (fun (name, width) ->
        framed name ^ Binary.u32 width) context.widths);
    Binary.u32 c.n_pub_out; Binary.u32 c.n_pub_in; Binary.u32 c.n_priv;
    Binary.u32 c.n_wires; Binary.u64 (List.length rows);
    String.concat "" (List.map row rows);
  ]
