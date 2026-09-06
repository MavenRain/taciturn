(** The M0 surface tree, its printer and its recursive-descent parser,
    SPEC.md section 9.  [parse] returns a result and never leaves the
    result track:  no OCaml failure is thrown and none is caught.

    Carried as algorithm from kanon de40d65 surface/parser.ml and
    surface/syntax.ml.  The [let*] walk over a token list that no step changes, the
    speculative binder group that commits only when the closing
    parenthesis is followed by the operator, the arrow fold, the
    left-associative application loop, the atom table and the three
    printing levels are kanon's.  kanon's case production, its mu group,
    its five nat primitives and its motive record have no taciturn Stage
    A production and are left out;  the checker that would read them
    lands at Stage B.

    One addition, D-M0-3:  ZKMARK is the keyword pair "zk def", which
    reads as an attribute on def, so "zk def n : A := t" parses to the
    same declaration node as "def n : A := t" with its zk flag set.  The
    second addition, WMARK, is the binder mark "w" of [mark_prefix]
    below, so a binder reads "(w x : Field p)" and the three marks map to
    [Quantity.Zero], [Quantity.W] and [Quantity.One], with an absent mark
    mapping to [Quantity.Many] as kanon maps it.

    No node holds a position, so two trees compare with structural
    equality and the round trip needs no position normalisation.  No
    constructor here spells a shape name and no production is a former:
    every form below maps to one kernel constructor through the sugar
    table of SPEC.md section 7. *)

open Taciturn_kernel

(** A binder, SPEC.md section 9:  "(" mark? name ":" term ")".  kanon
    de40d65 surface/syntax.ml:31-35. *)
type binder = {
  b_q : Quantity.t;
  b_name : string;
  b_ty : t;
}

(* kanon de40d65 surface/syntax.ml:88-117 *)
and t =
  | SVar of string
  | SNat of int
  | SProp
  | SType of int
  | SUnit
  | SAuto
  | SPair of t * t
  | STuple of t list
  | SSum of t list
  | SProd of t list
  | SProj of t * int
  | SInj of int * int * t
  | SAbsurd of t
  | SApp of t * t
  | SFun of binder list * t
  | SArrow of binder * t
  | SStar of binder * t
  | SLet of string * t * t * t
  | SAnn of t * t

(** A declaration.  The first field of [DDef] is the zk flag of D-M0-3:
    [true] under the ZKMARK keyword pair and [false] under a plain def.
    kanon de40d65 surface/syntax.ml:119-121. *)
type decl =
  | DDef of bool * string * t * t
  | DAxiom of string * t

(** Printing levels, loosest first.  Level 0 is a whole term, level 1 an
    application and level 2 an atom.  A node printed where a tighter
    level is wanted takes parentheses, which is the whole of the round
    trip discipline:  [print] never emits text that re-parses to another
    tree.  kanon de40d65 surface/syntax.ml:172-190. *)
let level_of (s : t) : int =
  match s with
  | SVar _ -> 2
  | SNat _ -> 2
  | SProp -> 2
  | SType _ -> 2
  | SUnit -> 2
  | SAuto -> 2
  | SPair (_, _) -> 2
  | STuple _ -> 2
  | SSum _ -> 2
  | SProd _ -> 2
  | SProj (_, _) -> 2
  | SAnn (_, _) -> 2
  | SInj (_, _, _) -> 0
  | SAbsurd _ -> 0
  | SApp (_, _) -> 1
  | SFun (_, _) -> 0
  | SArrow (_, _) -> 0
  | SStar (_, _) -> 0
  | SLet (_, _, _, _) -> 0

(** The binder marks as the surface spells them.  The witness mark is the
    D-M0-3 addition and an absent mark is [Quantity.Many]. *)
let mark (q : Quantity.t) : string =
  match q with
  | Quantity.Zero -> "0 "
  | Quantity.W -> "w "
  | Quantity.One -> "1 "
  | Quantity.Many -> ""

(* kanon de40d65 surface/syntax.ml:169-174 *)
let rec at (lvl : int) (s : t) : string =
  let text = raw s in
  if level_of s >= lvl then text else "(" ^ text ^ ")"

and binder_text (b : binder) : string =
  Printf.sprintf "(%s%s : %s)" (mark b.b_q) b.b_name (at 0 b.b_ty)

(* kanon de40d65 surface/syntax.ml:205-241 *)
and raw (s : t) : string =
  match s with
  | SVar x -> x
  | SNat n -> string_of_int n
  | SProp -> "Prop"
  | SType n -> "Type " ^ string_of_int n
  | SUnit -> "()"
  | SAuto -> "auto"
  | SPair (a, b) -> Printf.sprintf "(%s, %s)" (at 0 a) (at 0 b)
  | STuple items -> Printf.sprintf "tuple (%s)" (items_text items)
  | SSum items -> Printf.sprintf "sum (%s)" (items_text items)
  | SProd items -> Printf.sprintf "prod (%s)" (items_text items)
  | SProj (a, k) -> Printf.sprintf "%s.%d" (at 2 a) k
  | SInj (k, n, a) -> Printf.sprintf "inj %d of %d %s" k n (at 1 a)
  | SAbsurd a -> "absurd " ^ at 1 a
  | SApp (f, a) -> at 1 f ^ " " ^ at 2 a
  | SFun (bs, body) ->
      Printf.sprintf "fun %s => %s"
        (String.concat " " (List.map binder_text bs))
        (at 0 body)
  | SArrow (b, cod) -> binder_text b ^ " -> " ^ at 0 cod
  | SStar (b, cod) -> binder_text b ^ " * " ^ at 0 cod
  | SLet (x, ty, def, body) ->
      Printf.sprintf "let %s : %s := %s in %s" x (at 1 ty) (at 1 def) (at 0 body)
  | SAnn (a, ty) -> Printf.sprintf "(%s : %s)" (at 0 a) (at 0 ty)

(** The one bracketed item list of the grammar.  An empty list prints as
    the two-character form the lexer reads whole. *)
and items_text (items : t list) : string = String.concat ", " (List.map (at 0) items)

let def_word (zk : bool) : string = if zk then "zk def" else "def"

let decl_text (d : decl) : string =
  match d with
  | DDef (zk, name, ty, body) ->
      Printf.sprintf "%s %s : %s := %s\n" (def_word zk) name (at 0 ty) (at 0 body)
  | DAxiom (name, ty) -> Printf.sprintf "axiom %s : %s\n" name (at 0 ty)

(** The printer whose output re-parses to an equal tree.  An empty tree
    prints as the empty text, which parses back to the empty tree. *)
let print (ds : decl list) : string = String.concat "" (List.map decl_text ds)

let ( let* ) = Result.bind

let parse_err (l : Lexer.loc) (msg : string) : ('a, Error.t) result =
  Error (Error.Parse (msg, l.Lexer.line, l.Lexer.col))

let eof_err : ('a, Error.t) result =
  (* unreachable:  the lexer always materialises an [Eof] token *)
  parse_err Lexer.start "unexpected end of input"

(** One error shape per "wanted X, read Y" arm, so a new arm adds a name
    and no format.  kanon de40d65 surface/parser.ml:34-39. *)
let expected (what : string) (ts : Lexer.t list) : ('a, Error.t) result =
  match ts with
  | { Lexer.kind; loc } :: _rest ->
      parse_err loc (Printf.sprintf "expected %s, found %s" what (Lexer.describe kind))
  | [] -> eof_err

(* kanon de40d65 surface/parser.ml:41-58 *)
let kind_starts_atom (k : Lexer.kind) : bool =
  match k with
  | Lexer.Ident _ | Lexer.Nat _ | Lexer.LParen | Lexer.Unit | Lexer.KProp
  | Lexer.KType | Lexer.KAuto | Lexer.KTuple | Lexer.KSum | Lexer.KProd
  | Lexer.KMu | Lexer.KNu ->
      true
  | Lexer.RParen | Lexer.Colon | Lexer.ColonEq | Lexer.Arrow | Lexer.DArrow
  | Lexer.Star | Lexer.Comma | Lexer.Dot | Lexer.KDef | Lexer.KAxiom
  | Lexer.KZk | Lexer.KWMark | Lexer.KFun | Lexer.KLet | Lexer.KIn
  | Lexer.KInj | Lexer.KOf | Lexer.KAbsurd | Lexer.Eof ->
      false

let starts_atom (ts : Lexer.t list) : bool =
  match ts with
  | { Lexer.kind; loc = _ } :: _rest -> kind_starts_atom kind
  | [] -> false

(** The binder's mark, D-M0-3 and SPEC.md section 9.  "0" is the erased
    mark, "w" is the witness mark, "1" is the linear mark and an absent
    mark is the runtime one.  Total:  a token that is none of the three
    leaves the list where it was.  kanon de40d65
    surface/parser.ml:65-70. *)
let mark_prefix (ts : Lexer.t list) : Quantity.t * Lexer.t list =
  match ts with
  | { Lexer.kind = Lexer.Nat 0; loc = _ } :: rest -> (Quantity.Zero, rest)
  | { Lexer.kind = Lexer.KWMark; loc = _ } :: rest -> (Quantity.W, rest)
  | { Lexer.kind = Lexer.Nat 1; loc = _ } :: rest -> (Quantity.One, rest)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) as same -> (Quantity.Many, same)

(* kanon de40d65 surface/parser.ml:71-78 *)
let rec parse_term (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.KFun; loc = _ } :: rest -> parse_fun rest
  | { Lexer.kind = Lexer.KLet; loc = _ } :: rest -> parse_let rest
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> parse_arrow ts

(** "fun binder+ => body".  One binder at least;  the body reaches as far
    right as it can.  kanon de40d65 surface/parser.ml:80-89. *)
and parse_fun (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  let* first, rest = parse_binder ts in
  let* binders, rest2 = parse_binders rest [ first ] in
  match rest2 with
  | { Lexer.kind = Lexer.DArrow; loc = _ } :: rest3 ->
      let* body, rest4 = parse_term rest3 in
      Ok (SFun (binders, body), rest4)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "'=>'" rest2

(** Zero or more binders, oldest first.  Total over a list that opens
    with no parenthesis.  kanon de40d65 surface/parser.ml:91-98. *)
and parse_binders (ts : Lexer.t list) (acc : binder list) :
    (binder list * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.LParen; loc = _ } :: _rest ->
      let* b, rest = parse_binder ts in
      parse_binders rest (b :: acc)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> Ok (List.rev acc, ts)

(** binder ::= '(' ('0' | 'w' | '1')? name ':' term ')'.  kanon de40d65
    surface/parser.ml:100-115. *)
and parse_binder (ts : Lexer.t list) : (binder * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.LParen; loc = _ } :: rest -> (
      let q, rest_q = mark_prefix rest in
      match rest_q with
      | { Lexer.kind = Lexer.Ident x; loc = _ }
        :: { Lexer.kind = Lexer.Colon; loc = _ }
        :: rest2 -> (
          let* ty, rest3 = parse_term rest2 in
          match rest3 with
          | { Lexer.kind = Lexer.RParen; loc = _ } :: rest4 ->
              Ok ({ b_q = q; b_name = x; b_ty = ty }, rest4)
          | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "')'" rest3)
      | ({ Lexer.kind = _; loc = _ } :: _ | []) ->
          expected "a binder name and ':'" rest_q)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "'('" ts

(** "let x : A := d in b".  kanon de40d65 surface/parser.ml:117-138. *)
and parse_let (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.Ident x; loc = _ }
    :: { Lexer.kind = Lexer.Colon; loc = _ }
    :: rest -> (
      let* ty, rest2 = parse_term rest in
      match rest2 with
      | { Lexer.kind = Lexer.ColonEq; loc = _ } :: rest3 -> (
          let* def, rest4 = parse_term rest3 in
          match rest4 with
          | { Lexer.kind = Lexer.KIn; loc = _ } :: rest5 ->
              let* body, rest6 = parse_term rest5 in
              Ok (SLet (x, ty, def, body), rest6)
          | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "'in'" rest4)
      | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "':='" rest2)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "a name and ':' after 'let'" ts

(** The arrow and the star, the loosest operators, both right
    associative.  kanon de40d65 surface/parser.ml:227-231. *)
and parse_arrow (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  binder_group_attempt ts
  |> Option.fold ~none:parse_arrow_plain ~some:(fun ((b : binder), rest) ->
         fun (_ts : Lexer.t list) -> parse_group_op b rest)
  |> fun k -> k ts

(** Speculative "(mark? x : T)".  Any inner failure, and any group that
    no operator follows, is [None] and the caller re-reads the same
    tokens as an ordinary term.  kanon de40d65
    surface/parser.ml:237-249. *)
and binder_group_attempt (ts : Lexer.t list) : (binder * Lexer.t list) option =
  match ts with
  | { Lexer.kind = Lexer.LParen; loc = _ } :: _rest ->
      parse_binder ts
      |> Result.fold
           ~ok:(fun ((b : binder), rest) ->
             match rest with
             | { Lexer.kind = Lexer.Arrow; loc = _ } :: _r -> Some (b, rest)
             | { Lexer.kind = Lexer.Star; loc = _ } :: _r -> Some (b, rest)
             | ({ Lexer.kind = _; loc = _ } :: _ | []) -> None)
           ~error:(fun (_e : Error.t) -> None)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> None

(* kanon de40d65 surface/parser.ml:250-262 *)
and parse_group_op (b : binder) (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.Arrow; loc = _ } :: rest ->
      let* cod, rest2 = parse_term rest in
      Ok (SArrow (b, cod), rest2)
  | { Lexer.kind = Lexer.Star; loc = _ } :: rest ->
      let* cod, rest2 = parse_term rest in
      Ok (SStar (b, cod), rest2)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "'->' or '*'" ts

(** "A -> B" and "A * B", the binder-free forms.  Both name the binder
    "_", the name the printer writes back.  kanon de40d65
    surface/parser.ml:264-276. *)
and parse_arrow_plain (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  let* lhs, rest = parse_app ts in
  match rest with
  | { Lexer.kind = Lexer.Arrow; loc = _ } :: rest2 ->
      let* rhs, rest3 = parse_term rest2 in
      Ok (SArrow ({ b_q = Quantity.Many; b_name = "_"; b_ty = lhs }, rhs), rest3)
  | { Lexer.kind = Lexer.Star; loc = _ } :: rest2 ->
      let* rhs, rest3 = parse_term rest2 in
      Ok (SStar ({ b_q = Quantity.Many; b_name = "_"; b_ty = lhs }, rhs), rest3)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> Ok (lhs, rest)

(** Application by juxtaposition, left associative, and the two saturated
    prefix forms that read one application each.  kanon de40d65
    surface/parser.ml:278-286. *)
and parse_app (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.KInj; loc = _ } :: rest -> parse_inj rest
  | { Lexer.kind = Lexer.KAbsurd; loc = _ } :: rest ->
      let* a, rest2 = parse_app rest in
      Ok (SAbsurd a, rest2)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) ->
      let* head, rest = parse_atom ts in
      parse_app_rest head rest

(* kanon de40d65 surface/parser.ml:288-296 *)
and parse_inj (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.Nat k; loc = _ }
    :: { Lexer.kind = Lexer.KOf; loc = _ }
    :: { Lexer.kind = Lexer.Nat n; loc = _ }
    :: rest ->
      let* a, rest2 = parse_app rest in
      Ok (SInj (k, n, a), rest2)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "'K of N' after 'inj'" ts

(* kanon de40d65 surface/parser.ml:298-305 *)
and parse_app_rest (head : t) (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  match () with
  | () when starts_atom ts ->
      let* arg, rest = parse_atom ts in
      parse_app_rest (SApp (head, arg)) rest
  | () -> Ok (head, ts)

(** An atom with its postfix projections, which bind tighter than
    application.  kanon de40d65 surface/parser.ml:308-322. *)
and parse_atom (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  let* a, rest = parse_atom_head ts in
  parse_postfix a rest

and parse_postfix (a : t) (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.Dot; loc = _ } :: { Lexer.kind = Lexer.Nat k; loc = _ } :: rest ->
      parse_postfix (SProj (a, k)) rest
  | { Lexer.kind = Lexer.Dot; loc } :: _rest -> parse_err loc "expected a leg number after '.'"
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> Ok (a, ts)

(* kanon de40d65 surface/parser.ml:324-354 *)
and parse_atom_head (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.Ident x; loc = _ } :: rest -> Ok (SVar x, rest)
  | { Lexer.kind = Lexer.Nat n; loc = _ } :: rest -> Ok (SNat n, rest)
  | { Lexer.kind = Lexer.KProp; loc = _ } :: rest -> Ok (SProp, rest)
  | { Lexer.kind = Lexer.KType; loc = _ } :: { Lexer.kind = Lexer.Nat n; loc = _ } :: rest ->
      Ok (SType n, rest)
  | { Lexer.kind = Lexer.KType; loc = _ } :: rest -> Ok (SType 0, rest)
  | { Lexer.kind = Lexer.KAuto; loc = _ } :: rest -> Ok (SAuto, rest)
  | { Lexer.kind = Lexer.Unit; loc = _ } :: rest -> Ok (SUnit, rest)
  | { Lexer.kind = Lexer.KTuple; loc = _ } :: rest ->
      parse_items "tuple" (fun (xs : t list) -> STuple xs) rest
  | { Lexer.kind = Lexer.KSum; loc = _ } :: rest ->
      parse_items "sum" (fun (xs : t list) -> SSum xs) rest
  | { Lexer.kind = Lexer.KProd; loc = _ } :: rest ->
      parse_items "prod" (fun (xs : t list) -> SProd xs) rest
  | { Lexer.kind = Lexer.KMu; loc } :: _rest -> parse_err loc "mu arrives at M1"
  | { Lexer.kind = Lexer.KNu; loc } :: _rest -> parse_err loc "nu arrives at M2"
  | { Lexer.kind = Lexer.LParen; loc = _ } :: rest -> parse_paren rest
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "a term" ts

(** After "(":  a term and then ")", "," or ":".  kanon de40d65
    surface/parser.ml:358-379. *)
and parse_paren (ts : Lexer.t list) : (t * Lexer.t list, Error.t) result =
  let* inner, rest = parse_term ts in
  match rest with
  | { Lexer.kind = Lexer.RParen; loc = _ } :: rest2 -> Ok (inner, rest2)
  | { Lexer.kind = Lexer.Comma; loc = _ } :: rest2 -> (
      let* second, rest3 = parse_term rest2 in
      match rest3 with
      | { Lexer.kind = Lexer.RParen; loc = _ } :: rest4 -> Ok (SPair (inner, second), rest4)
      | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "')'" rest3)
  | { Lexer.kind = Lexer.Colon; loc = _ } :: rest2 -> (
      let* ty, rest3 = parse_term rest2 in
      match rest3 with
      | { Lexer.kind = Lexer.RParen; loc = _ } :: rest4 -> Ok (SAnn (inner, ty), rest4)
      | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "')'" rest3)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "')', ',' or ':'" rest

(** "WORD (t1, .., tn)", the one bracketed item list of the grammar.  The
    empty list is the one token "()", which the lexer reads whole, so
    both "sum ()" and "sum ( )" are the width zero form.  kanon de40d65
    surface/parser.ml:381-405. *)
and parse_items (word : string) (build : t list -> t) (ts : Lexer.t list) :
    (t * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.Unit; loc = _ } :: rest -> Ok (build [], rest)
  | { Lexer.kind = Lexer.LParen; loc = _ } :: rest -> parse_items_body word build rest
  | ({ Lexer.kind = _; loc = _ } :: _ | []) ->
      expected (Printf.sprintf "'(' after '%s'" word) ts

and parse_items_body (word : string) (build : t list -> t) (ts : Lexer.t list) :
    (t * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.RParen; loc = _ } :: rest -> Ok (build [], rest)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> parse_items_rest word build ts []

and parse_items_rest (word : string) (build : t list -> t) (ts : Lexer.t list)
    (acc : t list) : (t * Lexer.t list, Error.t) result =
  let* item, rest = parse_term ts in
  match rest with
  | { Lexer.kind = Lexer.Comma; loc = _ } :: rest2 ->
      parse_items_rest word build rest2 (item :: acc)
  | { Lexer.kind = Lexer.RParen; loc = _ } :: rest2 ->
      Ok (build (List.rev (item :: acc)), rest2)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "',' or ')'" rest

(** Declarations, oldest first, up to the [Eof] token.  kanon de40d65
    surface/parser.ml:407-413. *)
let rec parse_decls (ts : Lexer.t list) (acc : decl list) : (decl list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.Eof; loc = _ } :: _rest -> Ok (List.rev acc)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) ->
      let* d, rest = parse_decl ts in
      parse_decls rest (d :: acc)

(** "def NAME : A := t", "zk def NAME : A := t" and "axiom NAME : A".
    The ZKMARK pair of D-M0-3 reads as an attribute on def:  both def
    arms build the same node and differ in the flag alone.  kanon de40d65
    surface/parser.ml:415-437. *)
and parse_decl (ts : Lexer.t list) : (decl * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.KZk; loc = _ } :: { Lexer.kind = Lexer.KDef; loc = _ } :: rest ->
      parse_def true rest
  | { Lexer.kind = Lexer.KDef; loc = _ } :: rest -> parse_def false rest
  | { Lexer.kind = Lexer.KAxiom; loc = _ }
    :: { Lexer.kind = Lexer.Ident name; loc = _ }
    :: { Lexer.kind = Lexer.Colon; loc = _ }
    :: rest ->
      let* ty, rest2 = parse_term rest in
      Ok (DAxiom (name, ty), rest2)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) ->
      expected "'def NAME :', 'zk def NAME :' or 'axiom NAME :'" ts

and parse_def (zk : bool) (ts : Lexer.t list) : (decl * Lexer.t list, Error.t) result =
  match ts with
  | { Lexer.kind = Lexer.Ident name; loc = _ }
    :: { Lexer.kind = Lexer.Colon; loc = _ }
    :: rest -> (
      let* ty, rest2 = parse_term rest in
      match rest2 with
      | { Lexer.kind = Lexer.ColonEq; loc = _ } :: rest3 ->
          let* body, rest4 = parse_term rest3 in
          Ok (DDef (zk, name, ty, body), rest4)
      | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "':='" rest2)
  | ({ Lexer.kind = _; loc = _ } :: _ | []) -> expected "a name and ':' after 'def'" ts

(** The whole surface entry point:  text to declarations, on the result
    track from end to end.  kanon de40d65 surface/parser.ml:501-503. *)
let parse (src : string) : (decl list, Error.t) result =
  let* ts = Lexer.lex src in
  parse_decls ts []
