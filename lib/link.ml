(** The link step of M0-PLAN section 4 delta 3, Stage B brief 3.5.  The
    disclosure ledger of SPEC.md section 6 is the classifier:  a postulate
    whose name holds an [Extern] row becomes a [Global.Extern] with the
    disclosed per-argument quantity signature, a postulate whose name
    holds an [Axiom] row becomes a [Global.Axiom], and a postulate that
    takes a witness argument and holds no row at all refuses to link
    (verdict:297).  A definition that carries a ledger name is a clash,
    because the ledger declares a name that no file may define.

    Two things live here rather than in lib/check.ml.  The first is the
    walk that reads the head of an application spine and the position of
    the argument being applied, which is what lets the checker stamp an
    argument with the DISCLOSED mark of its position rather than with the
    binder mark the file wrote.  The second is the reader of the
    signature text, so the ledger keeps one spelling of a signature and
    no row is written twice.

    This file spells no shape name:  the binder walk goes through
    [Rules.binder_marks] and the address view through [Term.as_apt], so
    the R0-AUDIT leg stays clean over it. *)

(** SB-M3:  the one declassifier of the brief section 4.  The name is
    written once, here, so the exception is one named case and never a
    wildcard arm. *)
let declassifier : string = "prove"

(** The mark word of one binder of a signature text.  The ledger writes a
    binder as "(mark name : type)", so the word after the parenthesis is
    the mark, and a parenthesis that opens anything else yields no mark. *)
let mark_of_word (w : string) : Quantity.t option =
  match () with
  | () when String.equal w "0" -> Some Quantity.Zero
  | () when String.equal w "w" -> Some Quantity.W
  | () when String.equal w "1" -> Some Quantity.One
  | () when String.equal w "many" -> Some Quantity.Many
  | () -> None

let first_word (s : string) : string =
  match String.split_on_char ' ' s with
  | [] -> ""
  | w :: _rest -> w

(** The per-argument quantity signature the ledger discloses, outermost
    first.  [Global.check_signature] compares its length with the binder
    count of the type the file declares, so a file that writes a
    different arity is refused before any call is checked. *)
let marks_of_sig (text : string) : Quantity.t list =
  String.split_on_char '(' text
  |> List.filter_map (fun (piece : string) -> mark_of_word (first_word piece))

(** The head of an application spine and the number of arguments already
    applied under the node being checked, which is the index of the
    argument this node applies.  Only a global head carries a disclosed
    signature, so every other head answers [None]. *)
let rec spine_head (t : Term.t) (n : int) : (string * int) option =
  match t with
  | Term.Global g -> Some (g, n)
  | Term.Out (_s, _addr, inner) -> spine_head inner (n + 1)
  | Term.Var _ | Term.Univ _ | Term.Lan (_, _) | Term.Ran (_, _)
  | Term.In (_, _, _) | Term.Elim _ | Term.Sec (_, _) | Term.Let (_, _, _, _)
  | Term.Ann (_, _) | Term.Lit _ | Term.Auto ->
      None

(** SB-M2:  the disclosed mark of the position an argument sits at.  The
    walk asks the environment for the extern entry of the head and reads
    the mark at the index the spine gives, so the mark comes from the
    ledger and not from the binder mark the file wrote.  A head that is
    not an extern, or a position past the signature, answers [None] and
    the ordinary rule of the point shape stands alone. *)
let point_mark (globals : Global.t) (name : string) (k : int) : Quantity.t option =
  Global.find_extern name globals
  |> Option.map (fun (x : Global.extern_entry) -> x.Global.x_sig)
  |> Fun.flip Option.bind (Rules.at k)

let arg_mark (globals : Global.t) (scrut : Term.t) : Quantity.t option =
  spine_head scrut 0
  |> Fun.flip Option.bind
       (fun ((n : string), (k : int)) -> point_mark globals n k)

(** True when the disclosed signature of a head takes a witness argument,
    which is what makes a call a declassification. *)
let takes_witness (globals : Global.t) (name : string) : bool =
  Global.find_extern name globals
  |> Option.fold ~none:false ~some:(fun (x : Global.extern_entry) ->
         List.exists (Quantity.equal Quantity.W) x.Global.x_sig)

let not_a_declassifier (name : string) : Error.t =
  Error.Quantity
    (Printf.sprintf
       "the extern %s takes a witness argument and is not the declassifier %s, so its \
        result may not be read at a runtime mode"
       name declassifier)

(** The entry a postulate builds.  The ledger row decides the kind. *)
let of_row (name : string) (ty : Term.t) (r : Disclosure.row) :
    (Global.entry, Error.t) result =
  match r.Disclosure.d_kind with
  | Disclosure.Axiom ->
      if List.exists (Quantity.equal Quantity.W) (Rules.binder_marks ty) then
        Error (Error.Quantity ("the axiom " ^ name ^ " may not take witness arguments"))
      else Ok (Global.Axiom { Global.ax_ty = ty })
  | Disclosure.Extern ->
      let x : Global.extern_entry =
        {
          Global.x_ty = ty;
          import_tag = name;
          x_sig = marks_of_sig r.Disclosure.d_sig;
        }
      in
      Global.link_extern name x |> Result.map (fun () -> Global.Extern x)

(** A postulate with no ledger row.  One that takes a witness argument
    names a foreign implementation that touches witness data, so it is an
    extern and it refuses to link;  one that takes none is an ordinary
    believed statement. *)
let of_no_row (name : string) (ty : Term.t) : (Global.entry, Error.t) result =
  if List.exists (Quantity.equal Quantity.W) (Rules.binder_marks ty) then
    Error
      (Error.Extern_undisclosed
         (Printf.sprintf
            "the postulate %s takes a witness argument and has no row in the disclosure \
             ledger of SPEC.md section 6"
            name))
  else Ok (Global.Axiom { Global.ax_ty = ty })

let postulate (name : string) (ty : Term.t) : (Global.entry, Error.t) result =
  Disclosure.find name
  |> Option.fold
       ~none:(of_no_row name ty)
       ~some:(fun (r : Disclosure.row) -> of_row name ty r)

let clash (name : string) (r : Disclosure.row) : Error.t =
  let what : string =
    match r.Disclosure.d_kind with
    | Disclosure.Extern -> "a foreign implementation"
    | Disclosure.Axiom -> "a believed statement"
  in
  Error.Extern_clash
    (Printf.sprintf
       "the definition %s carries the name of %s in the disclosure ledger of SPEC.md \
        section 6, which no file defines"
       name what)

(** The refusal of the n04 negative:  a definition may not carry a ledger
    name, because the ledger declares what the file does not define. *)
let no_clash (name : string) : (unit, Error.t) result =
  Disclosure.find name
  |> Option.fold ~none:(Ok ())
       ~some:(fun (r : Disclosure.row) -> Error (clash name r))

(** Every postulate in the file contributes its checked type to the report.
    A ledger description supplements that type when a row exists. *)
let disclosure_line ((name : string), (entry : Global.entry)) : string option =
  let render (kind : string) (ty : Term.t) : string =
    let statement : string = name ^ " " ^ kind ^ " " ^ Pp.term [] ty in
    Disclosure.find name
    |> Option.fold ~none:statement ~some:(fun (r : Disclosure.row) ->
           statement ^ " | " ^ r.Disclosure.d_text ^ " | " ^ r.Disclosure.d_sig)
  in
  match entry with
  | Global.Axiom a -> Some (render "axiom" a.Global.ax_ty)
  | Global.Extern x -> Some (render "extern" x.Global.x_ty)
  | Global.Def _ | Global.Prim _ -> None
