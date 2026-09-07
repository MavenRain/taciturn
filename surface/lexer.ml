(** Lexer and token set of the taciturn M0 surface, SPEC.md section 9.
    The source is exploded to a char list once and everything after that
    is recursion over that list.

    Carried as algorithm from kanon de40d65 surface/lexer.ml and
    surface/token.ml.  The position type, the keyword table, [span],
    [nat_of_digits], the [go] walk and the "--" comment form are kanon's;
    the token set is taciturn's.  kanon's Dot1 and Dot2 tokens are left
    out:  one projection token reads ".1", ".2" and ".k" alike and the
    elaborator of Stage B separates the two sugar rows by the type of the
    scrutinee.

    Two additions, both D-M0-3:  [KZk], the first half of the ZKMARK
    keyword pair "zk def", and [KWMark], the WMARK binder mark "w" beside
    the marks "0" and "1".  "w" is a keyword and never a name, so a lexer
    that reads it as a name loses the mark and the parse test says so
    (SA-M3).  A lexical failure is [Error.Parse], the value the parser
    returns, so the surface has one error type. *)

open Taciturn_kernel

type loc = {
  line : int;
  col : int;
}

let start : loc = { line = 1; col = 1 }
let next_col (l : loc) : loc = { l with col = l.col + 1 }

(** [n] columns onward, which the two-character tokens want.  kanon
    de40d65 surface/token.ml:22. *)
let advance (l : loc) (n : int) : loc = { l with col = l.col + n }

let next_line (l : loc) : loc = { line = l.line + 1; col = 1 }

(** The token kinds of the M0 surface grammar.  [Unit] is the
    two-character form "()", one token because the grammar reads it as
    one form.  [KMu] and [KNu] are reserved:  the parser refuses both
    with their milestone name.  kanon de40d65 surface/token.ml:33-77. *)
type kind =
  | LParen
  | RParen
  | Colon
  | ColonEq
  | Arrow
  | DArrow
  | Star
  | Comma
  | Dot
  | Unit
  | KDef
  | KAxiom
  | KZk
  | KWMark
  | KFun
  | KLet
  | KIn
  | KInj
  | KOf
  | KAbsurd
  | KTuple
  | KSum
  | KProd
  | KProp
  | KType
  | KAuto
  | KMu
  | KNu
  | Ident of string
  | Nat of Bignum.t
  | Eof

type t = {
  kind : kind;
  loc : loc;
}

(* kanon de40d65 surface/token.ml:85-128 *)
let describe (k : kind) : string =
  match k with
  | LParen -> "'('"
  | RParen -> "')'"
  | Colon -> "':'"
  | ColonEq -> "':='"
  | Arrow -> "'->'"
  | DArrow -> "'=>'"
  | Star -> "'*'"
  | Comma -> "','"
  | Dot -> "'.'"
  | Unit -> "'()'"
  | KDef -> "'def'"
  | KAxiom -> "'axiom'"
  | KZk -> "'zk'"
  | KWMark -> "'w'"
  | KFun -> "'fun'"
  | KLet -> "'let'"
  | KIn -> "'in'"
  | KInj -> "'inj'"
  | KOf -> "'of'"
  | KAbsurd -> "'absurd'"
  | KTuple -> "'tuple'"
  | KSum -> "'sum'"
  | KProd -> "'prod'"
  | KProp -> "'Prop'"
  | KType -> "'Type'"
  | KAuto -> "'auto'"
  | KMu -> "'mu'"
  | KNu -> "'nu'"
  | Ident s -> Printf.sprintf "identifier %s" s
  | Nat n -> "number " ^ Bignum.to_string n
  | Eof -> "end of input"

let lex_err (l : loc) (msg : string) : ('a, Error.t) result =
  Error (Error.Parse (msg, l.line, l.col))

(* kanon de40d65 surface/lexer.ml:19-24 *)
let is_digit (c : char) : bool = c >= '0' && c <= '9'

let is_ident_start (c : char) : bool =
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || Char.equal c '_'

let is_ident_char (c : char) : bool = is_ident_start c || is_digit c || Char.equal c '\''

(** The eighteen keywords of the M0 surface.  "zk" and "w" are the two
    D-M0-3 additions.  kanon de40d65 surface/lexer.ml:28-57. *)
let keywords : (string * kind) list =
  [
    ("def", KDef); ("axiom", KAxiom); ("zk", KZk); ("w", KWMark);
    ("fun", KFun); ("let", KLet); ("in", KIn); ("inj", KInj);
    ("of", KOf); ("absurd", KAbsurd); ("tuple", KTuple); ("sum", KSum);
    ("prod", KProd); ("Prop", KProp); ("Type", KType); ("auto", KAuto);
    ("mu", KMu); ("nu", KNu);
  ]

(* kanon de40d65 surface/lexer.ml:59-60 *)
let ident_kind (s : string) : kind =
  List.assoc_opt s keywords |> Option.value ~default:(Ident s)

(** The longest prefix that satisfies [p], with the position just past it
    and the rest.  kanon de40d65 surface/lexer.ml:65-71. *)
let rec span (p : char -> bool) (l : loc) (cs : char list) : char list * loc * char list =
  match cs with
  | c :: rest when p c ->
      let taken, l2, rest2 = span p (next_col l) rest in
      (c :: taken, l2, rest2)
  | ([] | _ :: _) as same -> ([], l, same)

(* kanon c418062 surface/lexer.ml:76-79, Stage K arbitrary precision. *)
let nat_of_digits (l : loc) (digits : char list) : (Bignum.t, Error.t) result =
  List.to_seq digits |> String.of_seq |> Bignum.of_decimal
  |> Option.to_result ~none:(Error.Parse ("invalid natural literal", l.line, l.col))

(** The walk.  kanon de40d65 surface/lexer.ml:91-127, arm by arm. *)
let rec go (l : loc) (cs : char list) (acc : t list) : (t list, Error.t) result =
  match cs with
  | [] -> Ok (List.rev ({ kind = Eof; loc = l } :: acc))
  | ' ' :: rest | '\t' :: rest | '\r' :: rest -> go (next_col l) rest acc
  | '\n' :: rest -> go (next_line l) rest acc
  | '-' :: '-' :: rest -> skip_comment (advance l 2) rest acc
  | '-' :: '>' :: rest -> go (advance l 2) rest ({ kind = Arrow; loc = l } :: acc)
  | '=' :: '>' :: rest -> go (advance l 2) rest ({ kind = DArrow; loc = l } :: acc)
  | ':' :: '=' :: rest -> go (advance l 2) rest ({ kind = ColonEq; loc = l } :: acc)
  | ':' :: rest -> go (next_col l) rest ({ kind = Colon; loc = l } :: acc)
  | '(' :: ')' :: rest -> go (advance l 2) rest ({ kind = Unit; loc = l } :: acc)
  | '(' :: rest -> go (next_col l) rest ({ kind = LParen; loc = l } :: acc)
  | ')' :: rest -> go (next_col l) rest ({ kind = RParen; loc = l } :: acc)
  | '*' :: rest -> go (next_col l) rest ({ kind = Star; loc = l } :: acc)
  | ',' :: rest -> go (next_col l) rest ({ kind = Comma; loc = l } :: acc)
  | '.' :: rest -> go (next_col l) rest ({ kind = Dot; loc = l } :: acc)
  | c :: rest when is_digit c ->
      let taken, l2, rest2 = span is_digit (next_col l) rest in
      let digits = c :: taken in
      (* kanon c418062 surface/lexer.ml:120-124 *)
      Result.bind (nat_of_digits l digits) (fun n ->
        go l2 rest2 ({ kind = Nat n; loc = l } :: acc))
  | c :: rest when is_ident_start c ->
      let taken, l2, rest2 = span is_ident_char (next_col l) rest in
      let s = List.to_seq (c :: taken) |> String.of_seq in
      go l2 rest2 ({ kind = ident_kind s; loc = l } :: acc)
  | c :: _rest ->
      (* a lone '-', neither "--" nor "->", lands here too *)
      lex_err l (Printf.sprintf "unexpected character %C" c)

(** To the end of the line, advancing the column over the comment
    characters so the [Eof] position stays honest.  kanon de40d65
    surface/lexer.ml:132-137. *)
and skip_comment (l : loc) (cs : char list) (acc : t list) : (t list, Error.t) result =
  match cs with
  | [] -> go l [] acc
  | '\n' :: rest -> go (next_line l) rest acc
  | _other :: rest -> skip_comment (next_col l) rest acc

let lex (src : string) : (t list, Error.t) result =
  go start (String.to_seq src |> List.of_seq) []
