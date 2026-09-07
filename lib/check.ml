(* carried from kanon c418062 lib/check.ml, delta: W and Extern checking, split linear modes, duplicate global rejection, normalized linking, D-B-2 family declaration drop, and compacted comments *)
(** Bidirectional checking delegates shape rules to their packs. Sections,
    injections and motive-free eliminations need an expected type.
    Inference polls the supplied budget. Each checked expression carries
    pure path usage, discharged at One binder boundaries. Types contribute
    no runtime usage; witness readability and multiplicity remain separate. *)

let ( let* ) = Result.bind

type ctx = {
  globals : Global.t;
  env : Value.t list;  (** one value per local, innermost first *)
  locals : (string * Quantity.t * Value.t) list;  (** innermost first *)
  size : int;
  budget : Budget.t;
}

let make (globals : Global.t) (budget : Budget.t) : ctx =
  { globals; env = []; locals = []; size = 0; budget }

(** A bound local stands for itself, so its value is the variable at the
    level the context has grown to (kan-lang-tot-pin/lib/check.ml:27). *)
let bind (x : string) (q : Quantity.t) (ty : Value.t) (c : ctx) : ctx =
  {
    c with
    env = Value.var c.size :: c.env;
    locals = (x, q, ty) :: c.locals;
    size = c.size + 1;
  }

(** A let bound local stands for its definition. *)
let define (x : string) (q : Quantity.t) (ty : Value.t) (v : Value.t) (c : ctx) : ctx =
  { c with env = v :: c.env; locals = (x, q, ty) :: c.locals; size = c.size + 1 }

let budget_msg : string = "the check budget is exhausted"
let string_word : string = "string types arrive at M1"

let no_infer (what : string) : Error.t =
  Error.Cannot_infer (what ^ " has no type of its own;  it needs an expected type")

(** SB-M1 occurrence rule: Zero reads every binder; W reads every
    nonzero binder; One and Many read only One and Many. The declassifier
    below is the sole exception for a witness-consuming extern result. *)
let readable (mode : Quantity.t) (q : Quantity.t) : bool =
  match (mode, q) with
  | Quantity.Zero, Quantity.Zero -> true
  | Quantity.Zero, Quantity.W -> true
  | Quantity.Zero, Quantity.One -> true
  | Quantity.Zero, Quantity.Many -> true
  | Quantity.W, Quantity.Zero -> false
  | Quantity.W, Quantity.W -> true
  | Quantity.W, Quantity.One -> true
  | Quantity.W, Quantity.Many -> true
  | (Quantity.One | Quantity.Many), Quantity.Zero -> false
  | (Quantity.One | Quantity.Many), Quantity.W -> false
  | (Quantity.One | Quantity.Many), Quantity.One -> true
  | (Quantity.One | Quantity.Many), Quantity.Many -> true

let names_of (c : ctx) : string list =
  List.map
    (fun ((x : string), (_q : Quantity.t), (_ty : Value.t)) -> x)
    c.locals

(** Levels identify binders independently of spelling and shadowing.
    Unreachable eliminations have no returning runtime path to discharge. *)
let close ?(affine : bool = false) (c : ctx) (size : int) (mode : Linear.mode) (uses : Linear.usage) :
    (Linear.usage, Error.t) result =
  List.fold_left
    (fun acc (level, (name, q, _ty)) ->
      let* free = acc in
      if level < size then Ok free
      else if not (Linear.erased mode) && Quantity.equal q Quantity.One
              && not ((if affine then Linear.at_most_once else Linear.exactly_once) level free) then
        let message = if affine then "the linear alias " ^ name ^ " may be used at most once"
          else "the linear binder " ^ name ^ " must be used exactly once on every runtime path" in
        Error (Error.Usage message)
      else Ok (Linear.remove level free))
    (Ok uses) (List.mapi (fun ix local -> c.size - ix - 1, local) c.locals)

let rec ops : ctx Rules.ops =
  {
    Rules.o_infer = (fun (c : ctx) (q : Linear.mode) (t : Term.t) -> infer_uses c q t);
    o_check = (fun (c : ctx) (q : Linear.mode) (t : Term.t) (ty : Value.t) -> check_uses c q t ty);
    o_close = (fun c size mode uses -> close c size mode uses);
    o_argument = (fun c mode head q arg dom -> extern_point c mode head q arg dom);
    o_infer_univ = (fun (c : ctx) (t : Term.t) -> infer_univ c t);
    o_conv = (fun (c : ctx) ~(ty : Value.t) (a : Value.t) (b : Value.t) -> Conv.conv ops c ~ty a b);
    o_conv_type = (fun (c : ctx) (a : Value.t) (b : Value.t) -> Conv.conv_type ops c a b);
    o_eval = (fun (c : ctx) (t : Term.t) -> Eval.eval c.globals c.env t);
    o_whnf = (fun (c : ctx) (v : Value.t) -> Eval.whnf c.globals v);
    o_bind = (fun (x : string) (q : Quantity.t) (ty : Value.t) (c : ctx) -> bind x q ty c);
    o_size = (fun (c : ctx) -> c.size);
    o_env = (fun (c : ctx) -> c.env);
    o_ev = (fun (c : ctx) -> Eval.ev c.globals);
    o_pp = (fun (c : ctx) (v : Value.t) -> pp_value c v);
    o_quote = (fun (c : ctx) (v : Value.t) -> Eval.quote c.globals c.size v);
    o_head_ty = (fun (c : ctx) (h : Value.head) -> head_ty c h);
    (* M1 Stage G, brief 3.3:  the one accessor the mu pack reads a
       family record through (SG-D2).  This file holds no other family
       lookup on a checking path. *)
    o_family = (fun (c : ctx) (n : string) -> Global.find_family n c.globals);
  }

and pp_value (c : ctx) (v : Value.t) : string =
  Eval.quote c.globals c.size v
  |> Result.map (Pp.term (names_of c))
  |> Result.value ~default:"a value that does not read back"

(** The type a neutral head carries, which is what lets conversion walk a
    spine at a type. *)
and head_ty (c : ctx) (h : Value.head) : (Value.t, Error.t) result =
  match h with
  | Value.HLocal lvl ->
      Rules.at (c.size - lvl - 1) c.locals
      |> Option.to_result
           ~none:(Error.Unbound "a local level is outside the context")
      |> Result.map (fun ((_x : string), (_q : Quantity.t), (ty : Value.t)) -> ty)
  | Value.HGlobal n ->
      Global.find n c.globals
      |> Option.to_result ~none:(Error.Unbound n)
      |> Fun.flip Result.bind (fun (e : Global.entry) ->
             Eval.eval c.globals [] (Global.entry_ty e))

(** The universe a term lives at.  A type is read at mode [Zero], so an
    erased local may appear in it. *)
and infer_univ (c : ctx) (t : Term.t) : (Level.t, Error.t) result =
  let* v, _uses = infer_uses c (Linear.mode Quantity.Zero) t in
  let* w = Eval.whnf c.globals v in
  Value.as_univ w
  |> Option.to_result
       ~none:
         (Error.Universe
            ("a term used as a type is not a universe:  " ^ pp_value c w))

and infer_uses (c : ctx) (mode : Linear.mode) (t : Term.t) : (Value.t * Linear.usage, Error.t) result =
  if Budget.exhausted c.budget then Error (Error.Budget_exhausted budget_msg)
  else infer_node c mode t

and infer_node (c : ctx) (mode : Linear.mode) (t : Term.t) : (Value.t * Linear.usage, Error.t) result =
  match t with
  | Term.Var ix ->
      let* x, q, ty =
        Rules.at ix c.locals
        |> Option.to_result
             ~none:
               (Error.Unbound
                  (Printf.sprintf "de Bruijn index %d is outside the context" ix))
      in
      if readable mode.Linear.stamp q then Ok (ty, Linear.occurrence (c.size - ix - 1) mode)
      else
        Error
          (Error.Quantity
             (Printf.sprintf "the binder %s is marked %s and the point is stamped %s, so the occurrence rule of SPEC.md section 3.1 does not read it there" x (Quantity.to_string q) (Quantity.to_string mode.Linear.stamp)))
  | Term.Univ l -> Ok (Value.VUniv (Level.succ l), Linear.empty)
  | Term.Lan (s, diagram) ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules s in
      let* l = pack.Rules.form_lan ops c s diagram ~expected:None in
      Ok (Value.VUniv l, Linear.empty)
  | Term.Ran (s, diagram) ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules s in
      let* l = pack.Rules.form_ran ops c s diagram ~expected:None in
      Ok (Value.VUniv l, Linear.empty)
  | Term.Out (s, addr, scrut) ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules s in
      pack.Rules.elim_out ops c mode s addr scrut
  | Term.Elim e ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules e.Term.e_shape in
      pack.Rules.elim_elim ops c mode e ~expected:None
  | Term.Let (x, ty, def, body) ->
      let_body c mode x ty def (fun c' -> infer_uses c' mode body)
  | Term.Ann (tm, ty) ->
      let* _l = infer_univ c ty in
      let* tyv = Eval.eval c.globals c.env ty in
      let* uses = check_uses c mode tm tyv in
      Ok (tyv, uses)
  | Term.Global n ->
      let* () = declassify c mode.Linear.stamp n in
      let* ty = head_ty c (Value.HGlobal n) in
      Ok (ty, Linear.empty)
  | Term.Lit (Literal.LInt value) ->
      if Bignum.sign value < 0 then Error (Error.Mismatch "a Nat literal must be nonnegative")
      else
        let* ty = Eval.eval c.globals [] Prim.nat_ty in
        Ok (ty, Linear.empty)
  | Term.Lit (Literal.LString _) -> Error (Error.Not_yet string_word)
  | Term.In (_, _, _) -> Error (no_infer "an injection")
  | Term.Sec (_, _) -> Error (no_infer "a section")
  | Term.Auto -> Error (Error.Not_yet Rules.auto_word)

(** SB-M3:  prove is the one declassifier of the brief section 4.  An
    extern whose disclosed signature takes a witness argument computes on
    witness data, so its result reads where a W-marked binder reads and
    at no other mode.  The exception is the single name lib/link.ml
    holds, so it is one named case and never a wildcard. *)
and declassify (c : ctx) (mode : Quantity.t) (n : string) : (unit, Error.t) result =
  match () with
  | () when readable mode Quantity.W -> Ok ()
  | () when not (Link.takes_witness c.globals n) -> Ok ()
  | () when String.equal n Link.declassifier -> Ok ()
  | () -> Error (Link.not_a_declassifier n)

(** The ledger supplies the operational demand. A differing declaration
    still validates at its own stamp, but that view contributes no second
    usage. Both checks receive the domain, including check-only terms. *)
and extern_point (c : ctx) (mode : Linear.mode) (head : Term.t) (q : Quantity.t)
    (arg : Term.t) (dom : Value.t) : (Linear.usage, Error.t) result =
  let check_argument =
    Link.arg_mark c.globals head
    |> Option.fold
         ~none:(fun () -> check_uses c (Linear.multiply mode q) arg dom)
         ~some:(fun mark () ->
           let* uses = check_uses c (Linear.multiply mode mark) arg dom in
           let* () =
             if Quantity.equal mark q then Ok ()
             else Result.map (fun _uses -> ()) (check_uses c (Linear.multiply mode q) arg dom)
           in
           Ok uses)
  in
  check_argument ()

and check_uses (c : ctx) (mode : Linear.mode) (t : Term.t) (expected : Value.t) :
    (Linear.usage, Error.t) result =
  match t with
  | Term.Sec (s, legs) ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules s in
      pack.Rules.intro_sec ops c mode s legs ~expected
  | Term.In (s, addr, args) ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules s in
      pack.Rules.intro_in ops c mode s addr args ~expected
  | Term.Elim e ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules e.Term.e_shape in
      let* got, uses = pack.Rules.elim_elim ops c mode e ~expected:(Some expected) in
      let* () = ensure c got expected in
      Ok uses
  | Term.Lan (s, diagram) ->
      Result.map (fun () -> Linear.empty) (check_former c s diagram expected ~left:true)
  | Term.Ran (s, diagram) ->
      Result.map (fun () -> Linear.empty) (check_former c s diagram expected ~left:false)
  | Term.Let (x, ty, def, body) ->
      Result.map snd (let_body c mode x ty def (fun c' ->
        let* uses = check_uses c' mode body expected in Ok (expected, uses)))
  | Term.Var _ | Term.Univ _ | Term.Out (_, _, _) | Term.Ann (_, _) | Term.Global _
  | Term.Lit _ | Term.Auto ->
      let* got, uses = infer_uses c mode t in
      let* () = ensure c got expected in
      Ok uses

(** A former checked against a universe passes the expected level to the
    pack (SB-D6), which is what gives the width zero collection its
    universe (D-M0-6).  M0 has no cumulativity, so the level the pack
    reports must be the level expected (SB-D2). *)
and check_former (c : ctx) (s : Term.t Shape.t) (diagram : Term.t) (expected : Value.t)
    ~(left : bool) : (unit, Error.t) result =
  let* w = Eval.whnf c.globals expected in
  let* l0 =
    Value.as_univ w
    |> Option.to_result
         ~none:
           (Error.Universe
              ("a type former is checked against a type that is not a universe:  "
              ^ pp_value c w))
  in
  let* (pack : ctx Rules.rule_pack) = Rules.rules s in
  let former = if left then pack.Rules.form_lan else pack.Rules.form_ran in
  let* l = former ops c s diagram ~expected:(Some l0) in
  if Level.equal l l0 then Ok ()
  else
    Error
      (Error.Universe
         (Printf.sprintf "the former lives at %s and the expected universe is %s"
            (Level.to_string l) (Level.to_string l0)))

(** The subsumption step:  an inferred type must convert with the
    expected one.  There is no cumulativity at M0, so conversion is the
    whole relation. *)
and ensure (c : ctx) (got : Value.t) (expected : Value.t) : (unit, Error.t) result =
  let* eq = Conv.conv_type ops c got expected in
  if eq then Ok ()
  else
    Error
      (Error.Mismatch
         (Printf.sprintf "the term has type %s and the expected type is %s"
            (pp_value c got) (pp_value c expected)))

(** Eager definitions count once. An implicit alias carrying a linear
    resource is affine: its own reads may be zero or one, never duplicated. *)
and let_body (c : ctx) (mode : Linear.mode) (x : string) (ty : Term.t) (def : Term.t)
    (body : ctx -> (Value.t * Linear.usage, Error.t) result) :
    (Value.t * Linear.usage, Error.t) result =
  let* _l = infer_univ c ty in
  let* tyv = Eval.eval c.globals c.env ty in
  let* def_uses = check_uses c (Linear.runtime mode) def tyv in
  let* defv = Eval.eval c.globals c.env def in
  let linear = List.exists (fun (ix, (_name, q, _ty)) ->
    Quantity.equal q Quantity.One && Linear.used (c.size - ix - 1) def_uses)
    (List.mapi (fun ix local -> ix, local) c.locals) in
  let q = match () with
    | () when Linear.erased mode -> Quantity.Zero
    | () when linear -> Quantity.One
    | () when Quantity.equal mode.Linear.stamp Quantity.W -> Quantity.W
    | () -> Quantity.Many in
  let c' = define x q tyv defv c in
  let* result, uses = body c' in
  let* free = close ~affine:linear c' c.size mode uses in
  Ok (result, Linear.sequence (Linear.scale mode def_uses) free)

let infer (c : ctx) (mode : Quantity.t) (t : Term.t) : (Value.t, Error.t) result =
  Result.map fst (infer_uses c (Linear.mode mode) t)

let check (c : ctx) (mode : Quantity.t) (t : Term.t) (expected : Value.t) :
    (unit, Error.t) result =
  Result.map (fun _uses -> ()) (check_uses c (Linear.mode mode) t expected)

(** The two kinds of declaration M0 has.  A definition carries a body, an
    axiom does not (R-Q3). *)
type kind =
  | Definition
  | Postulate

type decl = {
  d_name : string;
  d_kind : kind;
  d_ty : Term.t;
  d_body : Term.t option;  (** [None] for a postulate *)
}

let missing_body (n : string) : Error.t =
  Error.Cannot_infer ("the definition " ^ n ^ " has no body")

(** Check one declaration against the environment built so far.  The name
    is added by the caller and only after this returns, so a self
    reference in the body is [Error (Unbound name)]. *)
let check_decl (globals : Global.t) (budget : Budget.t) (d : decl) :
    (Global.entry, Error.t) result =
  let* () =
    if Option.is_some (Global.find d.d_name globals) then
      Error (Error.Mismatch ("the global " ^ d.d_name ^ " is already declared"))
    else Ok ()
  in
  let c : ctx = make globals budget in
  let* _l = infer_univ c d.d_ty in
  let* tyv = Eval.eval globals [] d.d_ty in
  match d.d_kind with
  (* brief 3.5:  the disclosure ledger classifies a postulate, so an
     extern arrives with its per-argument signature and one with no row
     refuses to link (lib/link.ml). *)
  | Postulate ->
      let* ty = Eval.quote globals 0 tyv in
      Link.postulate d.d_name ty
  | Definition ->
      let* () = Link.no_clash d.d_name in
      let* body =
        d.d_body |> Option.to_result ~none:(missing_body d.d_name)
      in
      let* () = check c Quantity.Many body tyv in
      (* SB-D24:  M0 has no recursion, so unfolding ends and every
         definition is reducible with no guarded argument. *)
      Ok
        (Global.Def
           {
             Global.ty = d.d_ty;
             def = body;
             reducible = true;
             rec_arg = None;
             partial = false;
           })

(** Check a declaration list in order and return the checked entries in
    declaration order.  Each entry joins the environment the next
    declaration is checked against. *)
let check_decls ?(budget : Budget.t = Budget.unlimited) (globals : Global.t)
    (ds : decl list) : ((string * Global.entry) list, Error.t) result =
  List.fold_left
    (fun (acc : (Global.t * (string * Global.entry) list, Error.t) result) (d : decl) ->
      let* g, rows = acc in
      let* entry = check_decl g budget d in
      Ok (Global.add d.d_name entry g, (d.d_name, entry) :: rows))
    (Ok (globals, []))
    ds
  |> Result.map
       (fun ((_g : Global.t), (rows : (string * Global.entry) list)) -> List.rev rows)

(** Entry points for one term, for a driver and for the suite. *)
let infer_term ?(budget : Budget.t = Budget.unlimited) (globals : Global.t)
    (t : Term.t) : (Value.t, Error.t) result =
  infer (make globals budget) Quantity.Many t

let check_term ?(budget : Budget.t = Budget.unlimited) (globals : Global.t) (t : Term.t)
    (ty : Value.t) : (unit, Error.t) result =
  check (make globals budget) Quantity.Many t ty
