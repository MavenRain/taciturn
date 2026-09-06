(* carried from kanon de40d65 lib/error.ml, delta: this header line, the two extern arms Extern_signature and Extern_undisclosed of Stage B, brief 3.3, and the two Builder 2 arms Usage of the sum of SPEC.md section 3.2 and Extern_clash of the ledger name clash, brief 3.5 *)
(** Kernel and surface errors.  Stage B extends this sum with the check
    errors;  every consumer matches it exhaustively, so a new arm is a
    compile error at every reader before it is a silent fallthrough.

    [Not_yet] carries a milestone name, plan section 5:  rules.ml returns
    it for a shape that M0 does not admit, and the parser returns it
    through [Parse] for a surface word that M0 reserves.

    [message] returns the bare text and [to_string] adds the position, so
    a test can compare the text a producer chose without also fixing the
    position format.

    Stage B adds the check arms.  Each one carries its own text, so
    [message] stays the bare producer text that a negative fixture
    compares against (SB-D10) and [to_string] adds the decoration. *)

type t =
  | Not_yet of string
  | Parse of string * int * int
  | Carry of string
  | Unbound of string  (** a name with no binder and no declaration *)
  | Mismatch of string  (** the inferred type and the expected type differ *)
  | Universe of string  (** a term used as a type is not a universe *)
  | Quantity of string  (** an erased binder is read in a runtime position *)
  | Wrong_leg of string  (** a leg address is outside the collection *)
  | Missing_branch of string  (** an elimination does not cover every address *)
  | Overflow of string  (** a check-time literal leaves the host int range *)
  | Cannot_infer of string  (** the term has no type without an expectation *)
  | Budget_exhausted of string  (** the driver's cutoff fired (SB-D19) *)
  | Index_not_zero of string
      (** M1 Stage G:  an index binder of a family is not at quantity
          [Zero] (A2, kan-lang-tot-pin/lib/check.ml:1819) *)
  | Index_above_universe of string
      (** M1 Stage G:  an index type is above the declared level (A5,
          kan-lang-tot-pin/lib/check.ml:1820-1823) *)
  | Extern_signature of string
      (** M0 Stage B:  the length of the per-argument quantity signature
          of an extern differs from the binder count of its type, so the
          extern is refused before any call is checked (M0-PLAN section 4
          delta 3, brief 3.3) *)
  | Extern_undisclosed of string
      (** M0 Stage B:  an extern has no row in the disclosure ledger of
          SPEC.md section 6, so it refuses to link (M0-PLAN section 4
          delta 3, brief 3.3) *)
  | Usage of string
      (** M0 Stage B, brief 3.5:  the counted usage of a binder is not
          admissible in its declared mark (SPEC.md section 3.2).  The
          sum is a well-formedness check and not the occurrence rule, so
          it carries its own arm and a gate line names which rule
          refused *)
  | Extern_clash of string
      (** M0 Stage B, brief 3.5:  a definition carries the name of a row
          in the disclosure ledger, so the file would define a name the
          ledger declares as believed or as foreign *)

let message (e : t) : string =
  match e with
  | Not_yet m -> m
  | Parse (m, _, _) -> m
  | Carry m -> m
  | Unbound m -> m
  | Mismatch m -> m
  | Universe m -> m
  | Quantity m -> m
  | Wrong_leg m -> m
  | Missing_branch m -> m
  | Overflow m -> m
  | Cannot_infer m -> m
  | Budget_exhausted m -> m
  | Index_not_zero m -> m
  | Index_above_universe m -> m
  | Extern_signature m -> m
  | Extern_undisclosed m -> m
  | Usage m -> m
  | Extern_clash m -> m

let to_string (e : t) : string =
  match e with
  | Not_yet m -> "not yet: " ^ m
  | Parse (m, line, column) -> Printf.sprintf "line %d, column %d: %s" line column m
  | Carry m -> "carry: " ^ m
  | Unbound m -> "unbound: " ^ m
  | Mismatch m -> "mismatch: " ^ m
  | Universe m -> "universe: " ^ m
  | Quantity m -> "quantity: " ^ m
  | Wrong_leg m -> "wrong leg: " ^ m
  | Missing_branch m -> "missing branch: " ^ m
  | Overflow m -> "overflow: " ^ m
  | Cannot_infer m -> "cannot infer: " ^ m
  | Budget_exhausted m -> "budget: " ^ m
  | Index_not_zero m -> "index not zero: " ^ m
  | Index_above_universe m -> "index above universe: " ^ m
  | Extern_signature m -> "extern signature: " ^ m
  | Extern_undisclosed m -> "extern undisclosed: " ^ m
  | Usage m -> "usage: " ^ m
  | Extern_clash m -> "extern clash: " ^ m
