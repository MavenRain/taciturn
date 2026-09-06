(* carried from kanon de40d65 lib/check.ml, delta: this header line, the D-B-2 drop of the M1 family declaration path of 190 lines, which M0 does not read, the Builder 2 sites of brief 3.5, domain-directed extern argument checking, duplicate global rejection, normalized postulate linking, and compacted introductory comments *)
(** Bidirectional checking over the rule packs of the declared shapes.
    Sections, injections and motive-free eliminations need an expected type.
    Quantities are modes here; [Usage.body] checks the per-binder sums.
    Every inference polls the supplied budget. *)

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

(** SB-M1:  the occurrence rule of the Stage B brief section 4, which is
    NORMATIVE, and this is its one site.  No occurrence of a W-marked
    binder may sit at a One-stamped or a Many-stamped point.  As a total
    function of the pair (mode, mark), with mode the point and mark the
    binder:  at mode Zero every mark reads, because a Zero point exists
    at check time only;  at mode W the marks W, One and Many read and
    Zero does not;  at mode One and at mode Many the marks One and Many
    read, and Zero and W do not.  Twelve named pairs and no wildcard.
    The sole exception is the declassifier, which [declassify] below
    names once. *)
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

let rec ops : ctx Rules.ops =
  {
    Rules.o_infer = (fun (c : ctx) (q : Quantity.t) (t : Term.t) -> infer c q t);
    o_check = (fun (c : ctx) (q : Quantity.t) (t : Term.t) (ty : Value.t) -> check c q t ty);
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
  let* v = infer c Quantity.Zero t in
  let* w = Eval.whnf c.globals v in
  Value.as_univ w
  |> Option.to_result
       ~none:
         (Error.Universe
            ("a term used as a type is not a universe:  " ^ pp_value c w))

and infer (c : ctx) (mode : Quantity.t) (t : Term.t) : (Value.t, Error.t) result =
  if Budget.exhausted c.budget then Error (Error.Budget_exhausted budget_msg)
  else infer_node c mode t

and infer_node (c : ctx) (mode : Quantity.t) (t : Term.t) : (Value.t, Error.t) result =
  match t with
  | Term.Var ix ->
      let* x, q, ty =
        Rules.at ix c.locals
        |> Option.to_result
             ~none:
               (Error.Unbound
                  (Printf.sprintf "de Bruijn index %d is outside the context" ix))
      in
      if readable mode q then Ok ty
      else
        Error
          (Error.Quantity
             (Printf.sprintf
                "the binder %s is marked %s and the point is stamped %s, so the \
                 occurrence rule of SPEC.md section 3.1 does not read it there"
                x (Quantity.to_string q) (Quantity.to_string mode)))
  | Term.Univ l -> Ok (Value.VUniv (Level.succ l))
  | Term.Lan (s, diagram) ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules s in
      let* l = pack.Rules.form_lan ops c s diagram ~expected:None in
      Ok (Value.VUniv l)
  | Term.Ran (s, diagram) ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules s in
      let* l = pack.Rules.form_ran ops c s diagram ~expected:None in
      Ok (Value.VUniv l)
  | Term.Out (s, addr, scrut) ->
      let* () = extern_point c mode addr scrut in
      let* (pack : ctx Rules.rule_pack) = Rules.rules s in
      pack.Rules.elim_out ops c mode s addr scrut
  | Term.Elim e ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules e.Term.e_shape in
      pack.Rules.elim_elim ops c mode e ~expected:None
  | Term.Let (x, ty, def, body) ->
      let* c' = let_ctx c mode x ty def in
      infer c' mode body
  | Term.Ann (tm, ty) ->
      let* _l = infer_univ c ty in
      let* tyv = Eval.eval c.globals c.env ty in
      let* () = check c mode tm tyv in
      Ok tyv
  | Term.Global n ->
      let* () = declassify c mode n in
      Global.find n c.globals
      |> Option.to_result ~none:(Error.Unbound n)
      |> Fun.flip Result.bind (fun (e : Global.entry) ->
             Eval.eval c.globals [] (Global.entry_ty e))
  | Term.Lit (Literal.LInt _) -> Eval.eval c.globals [] Prim.nat_ty
  | Term.Lit (Literal.LString _) -> Error (Error.Not_yet string_word)
  | Term.In (_, _, _) -> Error (no_infer "an injection")
  | Term.Sec (_, _) -> Error (no_infer "a section")
  | Term.Auto -> Error (Error.Not_yet Rules.auto_word)

(** SB-M2:  the Extern signature of the brief section 4, at every call.
    The argument of a point is stamped with the mark the disclosure
    ledger holds for its position, outermost first, and not with the
    binder mark the file wrote, so a witness argument that the file
    marks w but the ledger stamps One or Many is refused by the
    occurrence rule above with no second mechanism.  A head that carries
    no disclosed signature, or a position past the signature, leaves the
    rule of the point shape standing alone. *)
and extern_point (c : ctx) (mode : Quantity.t) (addr : Term.addr) (scrut : Term.t) :
    (unit, Error.t) result =
  Option.bind (Term.as_apt addr)
    (fun ((_q : Quantity.t), (arg : Term.t)) ->
      Link.arg_mark c.globals scrut
      |> Option.map (fun (mark : Quantity.t) -> (arg, mark)))
  |> Option.fold ~none:(Ok ())
       ~some:(fun ((arg : Term.t), (mark : Quantity.t)) ->
         let* head_ty = infer c mode scrut in
         let* w = Eval.whnf c.globals head_ty in
         let* _q, _x, dom =
           Option.bind (Value.as_ran w) (fun (s, _clo, _u) -> Rules.as_vpi s)
           |> Option.to_result ~none:(Error.Mismatch "the head of an application is not a function")
         in
         check c (Quantity.mul mode mark) arg dom)

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

and check (c : ctx) (mode : Quantity.t) (t : Term.t) (expected : Value.t) :
    (unit, Error.t) result =
  match t with
  | Term.Sec (s, legs) ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules s in
      pack.Rules.intro_sec ops c mode s legs ~expected
  | Term.In (s, addr, args) ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules s in
      pack.Rules.intro_in ops c mode s addr args ~expected
  | Term.Elim e ->
      let* (pack : ctx Rules.rule_pack) = Rules.rules e.Term.e_shape in
      let* got = pack.Rules.elim_elim ops c mode e ~expected:(Some expected) in
      ensure c got expected
  | Term.Lan (s, diagram) -> check_former c s diagram expected ~left:true
  | Term.Ran (s, diagram) -> check_former c s diagram expected ~left:false
  | Term.Let (x, ty, def, body) ->
      let* c' = let_ctx c mode x ty def in
      check c' mode body expected
  | Term.Var _ | Term.Univ _ | Term.Out (_, _, _) | Term.Ann (_, _) | Term.Global _
  | Term.Lit _ | Term.Auto ->
      let* got = infer c mode t in
      ensure c got expected

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

(** A let binds its definition, so the body sees the value and not only
    the name.  The local carries the mode the let was read at, so an
    erased let stays erased in its body. *)
and let_ctx (c : ctx) (mode : Quantity.t) (x : string) (ty : Term.t) (def : Term.t) :
    (ctx, Error.t) result =
  let* _l = infer_univ c ty in
  let* tyv = Eval.eval c.globals c.env ty in
  let* () = check c mode def tyv in
  let* defv = Eval.eval c.globals c.env def in
  Ok (define x mode tyv defv c)

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
      (* brief 3.5:  the sum of SPEC.md section 3.2 rides beside the
         occurrence rule as a well-formedness check, with its own error
         constructor (lib/usage.ml). *)
      let* () = Usage.body body in
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
