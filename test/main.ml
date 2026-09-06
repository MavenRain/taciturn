(** The parse test of Stage A, brief section 3.8.  Every .tac file of the
    fixtures directory parses, prints, parses again, and the two
    declaration lists compare with structural equality.  The exit value
    is 0 when every file passes and 1 otherwise, so the PARSE gate reads
    one line.

    The directory listing goes through [Sys.command] and a text file
    because the house rules keep the vector type of [Sys.readdir] out of
    this repository.  A listing that does not come back leaves an empty
    list, which prints PARSE-FAIL 0/0, so a lost directory fails loudly.

    Each file also prints its mark product, the fold of every binder mark
    of the file under [Quantity.mul].  The a11 fixture holds one witness
    binder and one linear binder, so its product is the witness mark and
    the mul table of lib/quantity.ml has a printed reader (SA-M1). *)

open Taciturn_kernel
open Taciturn_surface

let temp_listing : string =
  Filename.concat (Filename.get_temp_dir_name ()) "taciturn-parse-listing.txt"

(** The one place that catches a host failure.  [In_channel] signals a
    missing path with [Sys_error];  the empty text is the honest answer
    and the caller turns it into a FAIL row. *)
let text_of (path : string) : string =
  try In_channel.with_open_text path In_channel.input_all with Sys_error _m -> ""

let is_tac (file : string) : bool = String.equal (Filename.extension file) ".tac"

let listing (dir : string) : string list =
  let cmd =
    Printf.sprintf "ls %s > %s 2>/dev/null" (Filename.quote dir) (Filename.quote temp_listing)
  in
  let code = Sys.command cmd in
  let raw = if Int.equal code 0 then text_of temp_listing else "" in
  String.split_on_char '\n' raw |> List.filter is_tac |> List.sort String.compare

(** The mark product of a declaration list.  [Quantity.One] is the unit
    of [Quantity.mul], so a file with no binder prints "1". *)
let rec marks_of (s : Parser.t) : Quantity.t list =
  match s with
  | Parser.SVar _ | Parser.SNat _ | Parser.SProp | Parser.SType _ | Parser.SUnit
  | Parser.SAuto ->
      []
  | Parser.SPair (a, b) -> marks_of a @ marks_of b
  | Parser.STuple items | Parser.SSum items | Parser.SProd items ->
      List.concat_map marks_of items
  | Parser.SProj (a, _) -> marks_of a
  | Parser.SInj (_, _, a) -> marks_of a
  | Parser.SAbsurd a -> marks_of a
  | Parser.SApp (f, a) -> marks_of f @ marks_of a
  | Parser.SFun (bs, body) -> List.concat_map marks_of_binder bs @ marks_of body
  | Parser.SArrow (b, cod) | Parser.SStar (b, cod) -> marks_of_binder b @ marks_of cod
  | Parser.SLet (_, ty, def, body) -> marks_of ty @ marks_of def @ marks_of body
  | Parser.SAnn (a, ty) -> marks_of a @ marks_of ty

and marks_of_binder (b : Parser.binder) : Quantity.t list =
  b.Parser.b_q :: marks_of b.Parser.b_ty

let marks_of_decl (d : Parser.decl) : Quantity.t list =
  match d with
  | Parser.DDef (_, _, ty, body) -> marks_of ty @ marks_of body
  | Parser.DAxiom (_, ty) -> marks_of ty

let product (ds : Parser.decl list) : Quantity.t =
  List.concat_map marks_of_decl ds |> List.fold_left Quantity.mul Quantity.One

(** parse, print, parse again, compare.  The declaration type holds no
    position and no function, so structural equality is the comparison
    the brief asks in one operator. *)
let ( let* ) = Result.bind

let round_trip (src : string) : (Parser.decl list, string) result =
  let* ds = Parser.parse src |> Result.map_error Error.to_string in
  let* again =
    Parser.parse (Parser.print ds)
    |> Result.map_error (fun (e : Error.t) ->
           "the printed text does not parse: " ^ Error.to_string e)
  in
  if ds = again then Ok ds else Error "the printed text parses to another tree"

let check (dir : string) (file : string) : bool =
  let name = Filename.remove_extension file in
  round_trip (text_of (Filename.concat dir file))
  |> Result.fold
       ~ok:(fun (ds : Parser.decl list) ->
         print_endline (Printf.sprintf "PARSE %s OK" name);
         print_endline (Printf.sprintf "MARK %s %s" name (Quantity.to_string (product ds)));
         true)
       ~error:(fun (m : string) ->
         print_endline (Printf.sprintf "PARSE %s FAIL: %s" name m);
         false)

let run (dir : string) : unit =
  let files = listing dir in
  let total = List.length files in
  let ok = List.filter (check dir) files |> List.length in
  let every = Int.equal ok total && total > 0 in
  print_endline
    (Printf.sprintf "%s %d/%d" (if every then "PARSE-OK" else "PARSE-FAIL") ok total);
  exit (if every then 0 else 1)

(** The default directory sits beside the executable because dune copies
    every source file of test/ into the build tree.  [Arg] hands the
    first plain argument to [run], which always leaves through [exit], so
    the last line runs only with no argument at all. *)
let default_dir : string = Filename.concat (Filename.dirname Sys.executable_name) "fixtures"

let () =
  Arg.parse [] run "usage: main.exe FIXTURES-DIR";
  run default_dir
