(** The elaborator, surface tree to kernel term.  Carried as algorithm
    from kanon de40d65 surface/elab.ml, not byte for byte, so this file
    holds no carry header and dev/CARRIED.md wants no row for it;  the
    kanon line each mirrored function comes from is cited above it.

    M0 elaborates the point shape and the two universes.  The collection
    and pair shapes carry rule packs in lib/rules.ml already, and their
    surface forms elaborate at Stage C, so each one answers
    [Error.Not_yet] with its milestone name rather than a wildcard arm.

    Elaboration reads a type out of a head at mode [Zero], because at
    mode Zero every mark reads:  elaboration builds a term and never
    refuses an occurrence, so the occurrence rule of lib/check.ml fires
    once, on the checking pass, and a refusal names one rule.

    The zk attribute of D-M0-3 rides the surface declaration and reaches
    no kernel constructor at M0;  Stage C reads it for the two
    erasures. *)

open Taciturn_kernel

let ( let* ) = Result.bind

let stage_c (what : string) : Error.t =
  Error.Not_yet (what ^ " elaborates at Stage C")

(* kanon de40d65 surface/elab.ml:37-41 *)
let rec index_of (x : string) (names : string list) : int option =
  match names with
  | [] -> None
  | y :: rest ->
      if String.equal x y then Some 0 else Option.map succ (index_of x rest)

(* kanon c418062 surface/elab.ml:61-64, sharing the parser's structural
   bound and reserving both the surface offset and the checker successor. *)
let level_of_int (n : int) : (Level.t, Error.t) result =
  let invalid = Error.Universe "surface universe level is outside the supported range" in
  let* bounded =
    Parser.bounded_nat Lexer.start (Bignum.of_int n)
    |> Result.map_error (fun (_e : Error.t) -> invalid)
  in
  if bounded >= Stdlib.max_int - 1 then Error invalid
  else Level.of_int (bounded + 1) |> Option.to_result ~none:invalid

(* kanon de40d65 surface/elab.ml:43-53 *)
let globals_of (c : Check.ctx) : Global.t = c.Check.globals
let env_of (c : Check.ctx) : Value.t list = c.Check.env
let size_of (c : Check.ctx) : int = c.Check.size

let eval_in (c : Check.ctx) (t : Term.t) : (Value.t, Error.t) result =
  Eval.eval (globals_of c) (env_of c) t

let not_a_function : Error.t =
  Error.Mismatch "the head of an application is not a function"

(* kanon de40d65 surface/elab.ml:183-246 *)
let rec elab (c : Check.ctx) (s : Parser.t) : (Term.t, Error.t) result =
  match s with
  | Parser.SVar x ->
      index_of x (Check.names_of c)
      |> Option.fold
           ~none:(Ok (Term.Global x))
           ~some:(fun (ix : int) -> Ok (Term.Var ix))
  | Parser.SNat n -> Ok (Term.Lit (Literal.LInt n))
  | Parser.SProp -> Ok (Term.Univ Level.zero)
  | Parser.SType n -> level_of_int n |> Result.map (fun l -> Term.Univ l)
  | Parser.SUnit -> Ok Rules.unit_val
  | Parser.SAuto -> Ok Term.Auto
  | Parser.SApp (f, a) -> elab_app c f a
  | Parser.SFun (bs, body) -> elab_fun c bs body
  | Parser.SArrow (b, cod) -> elab_arrow c b cod
  | Parser.SLet (x, ty, def, body) -> elab_let c x ty def body
  | Parser.SAnn (a, ty) ->
      let* a' = elab c a in
      let* ty' = elab c ty in
      Ok (Term.Ann (a', ty'))
  | Parser.SPair (_, _) -> Error (stage_c "a pair")
  | Parser.STuple _ -> Error (stage_c "a tuple type")
  | Parser.SSum _ -> Error (stage_c "a sum type")
  | Parser.SProd _ -> Error (stage_c "a product type")
  | Parser.SProj (_, _) -> Error (stage_c "a projection")
  | Parser.SInj (_, _, _) -> Error (stage_c "an injection")
  | Parser.SAbsurd _ -> Error (stage_c "an empty elimination")
  | Parser.SStar (_, _) -> Error (stage_c "a dependent pair type")

(* kanon de40d65 surface/elab.ml:453-471:  the point of an application
   comes from the type of the head, so the shape the [Out] node carries
   is the arrow the head stands at and never a placeholder. *)
and elab_app (c : Check.ctx) (f : Parser.t) (a : Parser.t) :
    (Term.t, Error.t) result =
  let* f' = elab c f in
  let* fty = Check.infer c Quantity.Zero f' in
  let* w = Eval.whnf (globals_of c) fty in
  let* vs, _dclo, _u =
    Value.as_ran w |> Option.to_result ~none:not_a_function
  in
  let* q, x, dom_v =
    Rules.as_vpi vs |> Option.to_result ~none:not_a_function
  in
  let* dom = Eval.quote (globals_of c) (size_of c) dom_v in
  let* a' = elab c a in
  Ok (Term.Out (Shape.SPi (q, x, dom), Term.APt (q, a'), f'))

(* kanon de40d65 surface/elab.ml:507-520:  a lambda binds one point per
   binder, so a binder list is a nest of one leg sections. *)
and elab_fun (c : Check.ctx) (bs : Parser.binder list) (body : Parser.t) :
    (Term.t, Error.t) result =
  match bs with
  | [] -> elab c body
  | b :: rest ->
      let* dom = elab c b.Parser.b_ty in
      let* dom_v = eval_in c dom in
      let c' = Check.bind b.Parser.b_name b.Parser.b_q dom_v c in
      let* inner = elab_fun c' rest body in
      Ok
        (Term.Sec
           ( Shape.SPi (b.Parser.b_q, b.Parser.b_name, dom),
             [
               {
                 Term.l_binders = [ (b.Parser.b_q, b.Parser.b_name) ];
                 l_body = inner;
               };
             ] ))

(* kanon de40d65 surface/elab.ml:521-533 *)
and elab_arrow (c : Check.ctx) (b : Parser.binder) (cod : Parser.t) :
    (Term.t, Error.t) result =
  let* dom = elab c b.Parser.b_ty in
  let* dom_v = eval_in c dom in
  let c' = Check.bind b.Parser.b_name b.Parser.b_q dom_v c in
  let* cod' = elab c' cod in
  Ok (Rules.arrow b.Parser.b_q b.Parser.b_name dom cod')

(* kanon de40d65 surface/elab.ml:230-237 *)
and elab_let (c : Check.ctx) (x : string) (ty : Parser.t) (def : Parser.t)
    (body : Parser.t) : (Term.t, Error.t) result =
  let* ty' = elab c ty in
  let* tyv = eval_in c ty' in
  let* def' = elab c def in
  let* defv = eval_in c def' in
  let c' = Check.define x Quantity.Many tyv defv c in
  let* body' = elab c' body in
  Ok (Term.Let (x, ty', def', body'))

(** One surface declaration, elaborated against the globals built so far.
    A def carries a body and an axiom does not (R-Q3);  the disclosure
    ledger classifies the axiom in lib/link.ml, so the two surface forms
    of the closed grammar of SPEC.md section 2 reach all four global
    kinds. *)
let decl_of (globals : Global.t) (d : Parser.decl) : (Check.decl, Error.t) result =
  let c : Check.ctx = Check.make globals Budget.unlimited in
  match d with
  | Parser.DAxiom (name, ty) ->
      let* ty' = elab c ty in
      Ok
        {
          Check.d_name = name;
          d_kind = Check.Postulate;
          d_ty = ty';
          d_body = None;
        }
  | Parser.DDef ((_zk : bool), name, ty, body) ->
      let* ty' = elab c ty in
      let* body' = elab c body in
      Ok
        {
          Check.d_name = name;
          d_kind = Check.Definition;
          d_ty = ty';
          d_body = Some body';
        }

(* kanon de40d65 bin/kanon.ml:38-47:  the file, checked, with the entries
   it left behind.  Each declaration joins the environment the next one
   is elaborated and checked against, so a later declaration reads an
   earlier one and never itself. *)
let check_in ?(budget : Budget.t = Budget.unlimited) (globals : Global.t)
    (src : string) : ((string * Global.entry) list, Error.t) result =
  let* ds = Parser.parse src in
  List.fold_left
    (fun (acc : (Global.t * (string * Global.entry) list, Error.t) result)
         (d : Parser.decl) ->
      let* g, rows = acc in
      let* kd = decl_of g d in
      let* entry = Check.check_decl g budget kd in
      Ok (Global.add kd.Check.d_name entry g, (kd.Check.d_name, entry) :: rows))
    (Ok (globals, []))
    ds
  |> Result.map
       (fun ((_g : Global.t), (rows : (string * Global.entry) list)) ->
         List.rev rows)

let check ?(budget : Budget.t = Budget.unlimited) (src : string) :
    ((string * Global.entry) list, Error.t) result =
  check_in ~budget Global.initial src

(** All checked axioms and externs, including postulates outside the ledger. *)
let disclosure_lines (rows : (string * Global.entry) list) : string list =
  List.filter_map Link.disclosure_line rows
