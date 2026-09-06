(** The disclosure ledger of SPEC.md section 6, in code.  Every extern
    and every axiom of M0 has one row here and the table below is the
    same table SPEC.md prints, row by row and in the same order.

    An extern with no row refuses to link, which [require_row] states
    (M0-PLAN section 4 delta 3, verdict:297).  An axiom reaches this
    ledger and never the code section:  [sound] and [verify_reflect] are
    declared here with their text and no file defines them, so the two
    of them are believed and are named where a reader reads the
    trusted base.

    The module reads only [Error], so [Global] may read it and the
    module graph stays acyclic. *)

type kind =
  | Extern
  | Axiom

type row = {
  d_name : string;
  d_kind : kind;
  d_text : string;
  d_sig : string;
      (** the quantity signature as SPEC.md writes it, per argument and
          outermost first *)
}

(** The ten rows of SPEC.md section 6.  The four field accelerators,
    [select], the wire allocator, [prove] and [verifyRaw] are externs;
    [sound] and [verify_reflect] are the two axioms. *)
let rows : row list =
  [
    {
      d_name = "field.add";
      d_kind = Extern;
      d_text = "the sum of two field values at the prime p";
      d_sig = "(w a : Field p) -> (w b : Field p) -> Field p";
    };
    {
      d_name = "field.mul";
      d_kind = Extern;
      d_text = "the product of two field values at the prime p";
      d_sig = "(w a : Field p) -> (w b : Field p) -> Field p";
    };
    {
      d_name = "field.inv";
      d_kind = Extern;
      d_text = "the multiplicative inverse of a field value, with zero mapped to zero";
      d_sig = "(w a : Field p) -> Field p";
    };
    {
      d_name = "field.eq";
      d_kind = Extern;
      d_text = "the equality test of two field values, one for equal and zero for other";
      d_sig = "(w a : Field p) -> (w b : Field p) -> Field p";
    };
    {
      d_name = "select";
      d_kind = Extern;
      d_text =
        "the only elimination of a Bit, which returns the second argument at one and the \
         third at zero";
      d_sig = "(w b : Bit) -> (w x : Field p) -> (w y : Field p) -> Field p";
    };
    {
      d_name = "alloc";
      d_kind = Extern;
      d_text =
        "the wire allocator, which appends the rows of one call and returns the wire index \
         of its value";
      d_sig = "(w v : Field p) -> Wire";
    };
    {
      d_name = "prove";
      d_kind = Extern;
      d_text = "the declassifier, which reads a witness at w and returns a public proof";
      d_sig =
        "(many R : Circuit) -> (many x : Public) -> (w wit : Witness) -> Proof R x";
    };
    {
      d_name = "verifyRaw";
      d_kind = Extern;
      d_text =
        "the raw verifier, which returns one on an accepted proof and zero on any other";
      d_sig =
        "(many R : Circuit) -> (many x : Public) -> (many v : Proof R x) -> Field p";
    };
    {
      d_name = "sound";
      d_kind = Axiom;
      d_text = "verifyRaw R x v = 1 -> Exists w, R x w = 1, the soundness of the raw verifier";
      d_sig =
        "(many R : Circuit) -> (many x : Public) -> (many v : Proof R x) -> (many h : \
         verifyRaw R x v = 1) -> Exists w, R x w = 1";
    };
    {
      d_name = "verify_reflect";
      d_kind = Axiom;
      d_text = "a verifier output wire constrained to one gives the fibre Proof R x";
      d_sig =
        "(many R : Circuit) -> (many x : Public) -> (many o : Field p) -> (many h : o = 1) \
         -> Proof R x";
    };
  ]

let find (name : string) : row option =
  List.find_opt (fun (r : row) -> String.equal r.d_name name) rows

(** The names of one kind, in the order of the table.  [Extern] and
    [Axiom] are both asked for, so the walk takes the kind it wants and
    names both arms. *)
let names_of_kind (k : kind) : string list =
  List.filter_map
    (fun (r : row) ->
      match (r.d_kind, k) with
      | Extern, Extern -> Some r.d_name
      | Axiom, Axiom -> Some r.d_name
      | Extern, Axiom -> None
      | Axiom, Extern -> None)
    rows

(** The two axioms of M0-PLAN section 4 delta 3, declared and never
    defined.  A reader of the trusted base reads this list. *)
let axioms : string list = names_of_kind Axiom

let externs : string list = names_of_kind Extern

(** The refusal of verdict:297.  An extern with no row here never
    reaches the import section, so no foreign implementation enters the
    trusted base without a disclosed statement. *)
let require_row (name : string) : (unit, Error.t) result =
  if Option.is_some (find name) then Ok ()
  else
    Error
      (Error.Extern_undisclosed
         (Printf.sprintf
            "the extern %s has no row in the disclosure ledger of SPEC.md section 6" name))

(** One printed row of the axioms verb, name, kind, text and signature. *)
let to_line (r : row) : string =
  let k : string =
    match r.d_kind with
    | Extern -> "extern"
    | Axiom -> "axiom"
  in
  Printf.sprintf "%s %s %s | %s" r.d_name k r.d_text r.d_sig
