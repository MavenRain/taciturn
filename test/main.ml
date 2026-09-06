(** The kernel suite of the Stage B brief section 3.7.  The executable
    takes one directory.  A directory that holds a fixtures directory is
    the test root and runs three legs;  a directory of .tac files runs the
    parse leg alone, which is the Stage A behaviour the PARSE gate of
    stage-a-gates.sh reads.

    PARSE walks test/fixtures:  every file parses, prints, parses again,
    and the two declaration lists compare with structural equality.
    CHECK walks test/check:  every file parses, elaborates and checks
    against the initial environment.  NEG walks test/neg:  every file is
    refused, and the tag of the refusal, which is the text ahead of the
    first colon of the error line, names the Error constructor, so the leg
    asserts that every word of the tag appears in the name of the file.
    A parse error carries the tag "line N, column M", whose words appear
    in no file name, so a negative that fails to parse fails the leg.

    The exit value is 0 when the three legs pass and 1 otherwise, and an
    empty leg is a failure, so a lost directory is loud.

    The directory listing goes through [Sys.command] and a text file
    because the house rules keep the vector type of [Sys.readdir] out of
    this repository.  The text walks go through [String.to_seq] and
    [String.starts_with], which are total, so no range is computed and no
    partial slice appears.

    Each fixture also prints its mark product, the fold of every binder
    mark of the file under [Quantity.mul].  The a11 fixture holds one
    witness binder and one linear binder, so its product is the witness
    mark and the mul table of lib/quantity.ml has a printed reader
    (SA-M1). *)

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

let parse_one (dir : string) (file : string) : bool =
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

(** The CHECK leg.  A well typed file elaborates and checks against
    [Global.initial], which is what the check verb of the driver does. *)
let check_one (dir : string) (file : string) : bool =
  let name = Filename.remove_extension file in
  Elab.check (text_of (Filename.concat dir file))
  |> Result.fold
       ~ok:(fun (_rows : (string * Global.entry) list) ->
         print_endline (Printf.sprintf "CHECK %s OK" name);
         true)
       ~error:(fun (e : Error.t) ->
         print_endline (Printf.sprintf "CHECK %s FAIL: %s" name (Error.to_string e));
         false)

(** The tag of an error line, which is the text ahead of the first colon.
    [Error.to_string] writes the constructor name there in words, so
    "extern clash" is [Error.Extern_clash]. *)
let tag_of (e : Error.t) : string =
  match String.split_on_char ':' (Error.to_string e) with
  | [] -> ""
  | head :: _rest -> head

(** [needle] appears somewhere in [hay].  The walk drops one character at
    a time through the character sequence, so it computes no range. *)
let rec contains_seq (hay : char Seq.t) (needle : string) : bool =
  match hay () with
  | Seq.Nil -> String.starts_with ~prefix:needle ""
  | Seq.Cons ((_c : char), (rest : char Seq.t)) ->
      if String.starts_with ~prefix:needle (String.of_seq hay) then true
      else contains_seq rest needle

let contains (hay : string) (needle : string) : bool =
  contains_seq (String.to_seq hay) needle

(** The negative names the refusal it must print when every word of the
    tag appears in the name of the file. *)
let named (name : string) (tag : string) : bool =
  String.split_on_char ' ' tag |> List.for_all (contains name)

let neg_one (dir : string) (file : string) : bool =
  let name = Filename.remove_extension file in
  Elab.check (text_of (Filename.concat dir file))
  |> Result.fold
       ~ok:(fun (_rows : (string * Global.entry) list) ->
         print_endline (Printf.sprintf "NEG %s FAIL: the file checks" name);
         false)
       ~error:(fun (e : Error.t) ->
         let tag : string = tag_of e in
         let ok : bool = named name tag in
         print_endline
           (Printf.sprintf "NEG %s %s: %s" name (if ok then "OK" else "FAIL") tag);
         ok)

(** One leg.  An empty directory prints 0/0 and fails. *)
let leg (label : string) (one : string -> string -> bool) (dir : string) : bool =
  let files : string list = listing dir in
  let total : int = List.length files in
  let ok : int = List.filter (one dir) files |> List.length in
  let every : bool = Int.equal ok total && total > 0 in
  print_endline
    (Printf.sprintf "%s-%s %d/%d" label (if every then "OK" else "FAIL") ok total);
  every

let parse_only (dir : string) : unit = exit (if leg "PARSE" parse_one dir then 0 else 1)

(** The three legs in order, then the one line the SUITE gate reads.
    Every leg runs, so one failure never hides another. *)
let suite (dir : string) : unit =
  let p : bool = leg "PARSE" parse_one (Filename.concat dir "fixtures") in
  let c : bool = leg "CHECK" check_one (Filename.concat dir "check") in
  let n : bool = leg "NEG" neg_one (Filename.concat dir "neg") in
  let every : bool = p && c && n in
  print_endline (if every then "SUITE-KERNEL OK" else "SUITE-KERNEL FAIL");
  exit (if every then 0 else 1)

let run (dir : string) : unit =
  if Sys.file_exists (Filename.concat dir "fixtures") then suite dir else parse_only dir

(** The default directory sits beside the executable because dune copies
    every source file of test/ into the build tree.  [Arg] hands the
    first plain argument to [run], which always leaves through [exit], so
    the last line runs only with no argument at all. *)
let default_dir : string = Filename.dirname Sys.executable_name

let () =
  Arg.parse [] run "usage: main.exe TEST-DIR";
  run default_dir
