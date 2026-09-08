(** The elaborator, surface tree to kernel term.  Carried as algorithm
    from kanon c418062 surface/elab.ml, not byte for byte, so this file
    holds no carry header and dev/CARRIED.md wants no row for it;  the
    kanon line each mirrored function comes from is cited above it.

    The point and collection surface forms share the existing rule packs
    in lib/rules.ml.  Expected types flow into introductions, including
    nested pairs and tuples, without adding a kernel constructor.

    Elaboration reads a type out of a head at mode [Zero], because at
    mode Zero every mark reads:  elaboration builds a term and never
    refuses an occurrence, so the occurrence rule of lib/check.ml fires
    once, on the checking pass, and a refusal names one rule.

    The zk attribute of D-M0-3 rides the surface declaration and reaches
    no kernel constructor at M0;  the two erasures read it later, once
    they exist. *)

open Taciturn_kernel

let ( let* ) = Result.bind

(* kanon c418062 surface/elab.ml:30-31 *)
let no_expect (what : string) : Error.t =
  Error.Cannot_infer (what ^ " needs an expected type")

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

(* kanon c418062 lib/check.ml:259-265.  Every source type is checked
   before evaluation, and source values are checked at Zero before an
   elaboration step evaluates them.  This rejects untyped self application
   without discharging runtime linear obligations or exposing witnesses. *)
let eval_type (c : Check.ctx) (t : Term.t) : (Value.t, Error.t) result =
  let* _level = Check.infer_univ c t in
  eval_in c t

let eval_checked (c : Check.ctx) (t : Term.t) (expected : Value.t) :
    (Value.t, Error.t) result =
  let* () = Check.check c Quantity.Zero t expected in
  eval_in c t

(* kanon c418062 surface/elab.ml:50-57 *)
let whnf_in (c : Check.ctx) (v : Value.t) : (Value.t, Error.t) result =
  Eval.whnf (globals_of c) v

let type_of (c : Check.ctx) (t : Term.t) : (Value.t, Error.t) result =
  let* v = Check.infer c Quantity.Zero t in
  whnf_in c v

(* kanon c418062 surface/elab.ml:72-96, with one delta.  Collection widths
   come from the source item list, and expectations are read from the
   diagram.  A tuple whose expected type is not a collection of the same
   width is refused here, so the refusal names the tuple and not a nested
   introduction inside it. *)
let leg_expectations (c : Check.ctx) (expected : Value.t option) (n : int) :
    (Value.t option list, Error.t) result =
  let missing = List.init n (fun (_k : int) -> None) in
  expected
  |> Option.fold ~none:(Ok missing) ~some:(fun (ty : Value.t) ->
         let* w = whnf_in c ty in
         let* vs, dclo, _u =
           Value.as_ran w
           |> Option.to_result
                ~none:(Error.Mismatch "a tuple needs a right former as its expected type")
         in
         let* dn =
           Rules.as_vcoll vs
           |> Option.to_result
                ~none:(Error.Mismatch "a tuple needs a collection former")
         in
         let* () =
           if Int.equal dn n then Ok ()
           else Error (Error.Mismatch "the tuple width and the type width differ")
         in
         let* dlegs = Rules.coll_legs_of Check.ops c dclo in
         Rules.all_ok
           (List.mapi
              (fun (k : int) (_ty : Value.t option) ->
                Result.map Option.some (Rules.coll_leg_ty Check.ops c dlegs k))
              missing))

(* kanon c418062 surface/elab.ml:72-96,211-214.  Read only the chosen
   injection leg, so an explicit width never allocates a list of that
   width.  The kernel's injection rule reads its expected width, so this
   row also checks that the source width agrees with it. *)
let injection_expectation (c : Check.ctx) (expected : Value.t option)
    (k : int) (n : int) : (Value.t option, Error.t) result =
  let* () =
    if k >= 0 && k < n then Ok ()
    else Error (Error.Wrong_leg Rules.leg_msg)
  in
  expected
  |> Option.fold ~none:(Ok None) ~some:(fun (ty : Value.t) ->
         let* w = whnf_in c ty in
         let* vs, dclo, _u =
           Value.as_lan w
           |> Option.to_result
                ~none:(Error.Mismatch "an injection needs a left former as its expected type")
         in
         let* dn =
           Rules.as_vcoll vs
           |> Option.to_result
                ~none:(Error.Mismatch "an injection needs a collection former")
         in
         let* () =
           if Int.equal dn n then Ok ()
           else Error (Error.Mismatch "the injection width and the type width differ")
         in
         let* dlegs = Rules.coll_legs_of Check.ops c dclo in
         Result.map Option.some (Rules.coll_leg_ty Check.ops c dlegs k))

let not_a_function : Error.t =
  Error.Mismatch "the head of an application is not a function"

(* kanon c418062 surface/elab.ml:183-242.  The optional argument keeps
   the original [elab context surface] inference entry point. *)
let rec elab (c : Check.ctx) ?(expected : Value.t option = None) (s : Parser.t) :
    (Term.t, Error.t) result =
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
  | Parser.SFun (bs, body) -> elab_fun c ~expected bs body
  | Parser.SArrow (b, cod) -> elab_group c b cod ~left:false
  | Parser.SLet (x, ty, def, body) -> elab_let c ~expected x ty def body
  | Parser.SAnn (a, ty) ->
      let* ty' = elab c ty in
      let* tyv = eval_type c ty' in
      let* a' = elab c ~expected:(Some tyv) a in
      Ok (Term.Ann (a', ty'))
  | Parser.SPair (a, b) -> elab_pair c ~expected a b
  | Parser.STuple items ->
      let* legs = elab_items c ~expected items in
      Ok (Term.Sec (Shape.SColl (List.length items), List.map Rules.leg_of legs))
  | Parser.SSum items ->
      let* tys = Rules.all_ok (List.map (elab c) items) in
      Ok (Rules.sum_ty tys)
  | Parser.SProd items ->
      let* tys = Rules.all_ok (List.map (elab c) items) in
      Ok (Rules.prod_ty tys)
  | Parser.SProj (a, k) -> elab_proj c a k
  | Parser.SInj (k, n, a) ->
      let* payload_ty = injection_expectation c expected k n in
      let* payload = elab c ~expected:payload_ty a in
      Ok (Term.In (Shape.SColl n, Term.ALeg k, [ payload ]))
  | Parser.SAbsurd a ->
      let* scrut = elab c a in
      Ok
        (Term.Elim
           {
             Term.e_shape = Shape.SColl 0;
             e_scrut = scrut;
             e_scrut_q = Quantity.One;
             e_motive = None;
             e_branches = [];
           })
  | Parser.SStar (b, cod) -> elab_group c b cod ~left:true

(* kanon c418062 surface/elab.ml:248-259 *)
and elab_items (c : Check.ctx) ~(expected : Value.t option) (items : Parser.t list) :
    (Term.t list, Error.t) result =
  let* tys = leg_expectations c expected (List.length items) in
  let* pairs =
    Rules.zip items tys
    |> Option.to_result
         ~none:(Error.Mismatch "the item count and the leg count differ")
  in
  Rules.all_ok
    (List.map
       (fun ((item : Parser.t), (ty : Value.t option)) -> elab c ~expected:ty item)
       pairs)

(* kanon c418062 surface/elab.ml:264-282.  The point opens the dependent
   codomain, and its mark is copied without changing W to a runtime mark. *)
and elab_pair (c : Check.ctx) ~(expected : Value.t option) (a : Parser.t)
    (b : Parser.t) : (Term.t, Error.t) result =
  let* ty = expected |> Option.to_result ~none:(no_expect "a pair") in
  let* w = whnf_in c ty in
  let* vs, dclo, _u =
    Value.as_lan w
    |> Option.to_result
         ~none:(Error.Mismatch "a pair needs a left former as its expected type")
  in
  let* q, x, dom_v =
    Rules.as_vpi vs
    |> Option.to_result ~none:(Error.Mismatch "a pair needs a point former")
  in
  let* point = elab c ~expected:(Some dom_v) a in
  let* point_v = eval_checked c point dom_v in
  let* cod_v = Rules.open_closure (Eval.ev (globals_of c)) dclo [ point_v ] in
  let* fibre = elab c ~expected:(Some cod_v) b in
  let* dom_t = Eval.quote (globals_of c) (size_of c) dom_v in
  Ok (Term.In (Shape.SPi (q, x, dom_t), Term.APt (q, point), [ fibre ]))

and elab_proj (c : Check.ctx) (a : Parser.t) (k : int) : (Term.t, Error.t) result =
  let* scrut, w = elab_scrut c a in
  let* term, (_ty : Value.t) = proj_typed c scrut w k in
  Ok term

(* A projection scrutinee reports the type it already computed, so a chain
   of projections infers each prefix once instead of once per level.  Every
   other surface node keeps the original two step path, elaborate and then
   infer, and the arm lists all eighteen of them because a wildcard arm is
   banned. *)
and elab_scrut (c : Check.ctx) (a : Parser.t) : (Term.t * Value.t, Error.t) result =
  match a with
  | Parser.SProj (b, k) ->
      let* scrut, w = elab_scrut c b in
      proj_typed c scrut w k
  | Parser.SVar _ | Parser.SNat _ | Parser.SProp | Parser.SType _
  | Parser.SUnit | Parser.SAuto | Parser.SApp _ | Parser.SFun _
  | Parser.SArrow _ | Parser.SLet _ | Parser.SAnn _ | Parser.SPair _
  | Parser.STuple _ | Parser.SSum _ | Parser.SProd _ | Parser.SInj _
  | Parser.SAbsurd _ | Parser.SStar _ ->
      let* term = elab c a in
      let* w = type_of c term in
      Ok (term, w)

(* kanon c418062 surface/elab.ml:297-325.  The two former views are
   exclusive.  Thunks keep the unused projection row from running.  Each
   row returns the type of the projection it built, which the row already
   holds, so no caller re-infers the scrutinee. *)
and proj_typed (c : Check.ctx) (scrut : Term.t) (w : Value.t) (k : int) :
    (Term.t * Value.t, Error.t) result =
  let run_tuple () : (Term.t * Value.t, Error.t) result =
    let* vs, dclo, _u =
      Value.as_ran w
      |> Option.to_result
           ~none:(Error.Mismatch
                    "a projection reads a pair or a tuple, and this scrutinee is neither")
    in
    let* term = elab_leg_proj scrut vs k in
    let* dlegs = Rules.coll_legs_of Check.ops c dclo in
    let* leg_ty = Rules.coll_leg_ty Check.ops c dlegs k in
    let* ty = whnf_in c leg_ty in
    Ok (term, ty)
  in
  Value.as_lan w
  |> Option.fold ~none:run_tuple
       ~some:(fun ((vs : Value.t Shape.t), (dclo : Value.closure), (_u : Level.t option)) ->
         fun () -> elab_pair_proj c scrut vs dclo k)
  |> fun run -> run ()

(* kanon c418062 surface/elab.ml:330-363.  The shared rule helper freezes
   the same inferable motives for surface projections and pair eta. *)
and elab_pair_proj (c : Check.ctx) (scrut : Term.t) (vs : Value.t Shape.t)
    (dclo : Value.closure) (k : int) : (Term.t * Value.t, Error.t) result =
  let* q, x, dom_v =
    Rules.as_vpi vs
    |> Option.to_result ~none:(Error.Mismatch "a pair projection needs a point former")
  in
  let* which =
    (if Int.equal k 1 then Some 0 else if Int.equal k 2 then Some 1 else None)
    |> Option.to_result
         ~none:(Error.Wrong_leg "a pair carries the projections .1 and .2 only")
  in
  let* motive = Rules.proj_motive Check.ops c vs dclo q x dom_v which in
  let* dom_t = Eval.quote (globals_of c) (size_of c) dom_v in
  let term : Term.t =
    Term.Elim
      {
        Term.e_shape = Shape.SPi (q, x, dom_t);
        e_scrut = scrut;
        e_scrut_q = Quantity.One;
        e_motive = motive;
        e_branches = Rules.proj_branch q x which;
      }
  in
  (* The point of a pair stands at the domain, so the first projection
     already knows its type.  The second stands at the opened diagram,
     whose point is this very projection, so that row asks the checker. *)
  if Int.equal which 0 then whnf_in c dom_v |> Result.map (fun (ty : Value.t) -> (term, ty))
  else type_of c term |> Result.map (fun (ty : Value.t) -> (term, ty))

(* kanon c418062 surface/elab.ml:366-374.  Tuple projections are zero based. *)
and elab_leg_proj (scrut : Term.t) (vs : Value.t Shape.t) (k : int) :
    (Term.t, Error.t) result =
  let* n =
    Rules.as_vcoll vs
    |> Option.to_result
         ~none:(Error.Mismatch "a leg projection needs a collection former")
  in
  Ok (Term.Out (Shape.SColl n, Term.ALeg k, scrut))

(* kanon c418062 surface/elab.ml:453-469:  the point of an application
   comes from the type of the head, so the shape the [Out] node carries
   is the arrow the head stands at and never a placeholder. *)
and elab_app (c : Check.ctx) (f : Parser.t) (a : Parser.t) :
    (Term.t, Error.t) result =
  let* f' = elab c f in
  let* w = type_of c f' in
  let* vs, _dclo, _u =
    Value.as_ran w |> Option.to_result ~none:not_a_function
  in
  let* q, x, dom_v =
    Rules.as_vpi vs |> Option.to_result ~none:not_a_function
  in
  let* dom = Eval.quote (globals_of c) (size_of c) dom_v in
  let* a' = elab c ~expected:(Some dom_v) a in
  Ok (Term.Out (Shape.SPi (q, x, dom), Term.APt (q, a'), f'))

(* kanon c418062 surface/elab.ml:483-504 *)
and cod_of (c : Check.ctx) ~(expected : Value.t option) :
    (Value.t option, Error.t) result =
  expected
  |> Option.fold ~none:(Ok None) ~some:(fun (ty : Value.t) ->
         let* w = whnf_in c ty in
         Value.as_ran w
         |> Option.fold ~none:(Ok None)
              ~some:(fun ((vs : Value.t Shape.t), (dclo : Value.closure), (_u : Level.t option)) ->
                Rules.as_vpi vs
                |> Option.fold ~none:(Ok None)
                     ~some:(fun ((_q : Quantity.t), (_x : string), (_dom : Value.t)) ->
                       Result.map Option.some
                         (Rules.open_closure (Eval.ev (globals_of c)) dclo
                            [ Value.var (size_of c) ]))))

(* kanon c418062 surface/elab.ml:507-517:  a lambda binds one point per
   binder, so a binder list is a nest of one leg sections. *)
and elab_fun (c : Check.ctx) ~(expected : Value.t option)
    (bs : Parser.binder list) (body : Parser.t) :
    (Term.t, Error.t) result =
  match bs with
  | [] -> elab c ~expected body
  | b :: rest ->
      let* dom = elab c b.Parser.b_ty in
      let* dom_v = eval_type c dom in
      let c' = Check.bind b.Parser.b_name b.Parser.b_q dom_v c in
      let* cod = cod_of c ~expected in
      let* inner = elab_fun c' ~expected:cod rest body in
      Ok
        (Term.Sec
           ( Shape.SPi (b.Parser.b_q, b.Parser.b_name, dom),
             [
               {
                 Term.l_binders = [ (b.Parser.b_q, b.Parser.b_name) ];
                 l_body = inner;
               };
             ] ))

(* kanon c418062 surface/elab.ml:521-526 *)
and elab_group (c : Check.ctx) (b : Parser.binder) (cod : Parser.t) ~(left : bool) :
    (Term.t, Error.t) result =
  let* dom = elab c b.Parser.b_ty in
  let* dom_v = eval_type c dom in
  let c' = Check.bind b.Parser.b_name b.Parser.b_q dom_v c in
  let* cod' = elab c' cod in
  let shape = Shape.SPi (b.Parser.b_q, b.Parser.b_name, dom) in
  Ok (if left then Term.Lan (shape, cod') else Term.Ran (shape, cod'))

(* kanon c418062 surface/elab.ml:230-237 *)
and elab_let (c : Check.ctx) ~(expected : Value.t option)
    (x : string) (ty : Parser.t) (def : Parser.t)
    (body : Parser.t) : (Term.t, Error.t) result =
  let* ty' = elab c ty in
  let* tyv = eval_type c ty' in
  let* def' = elab c ~expected:(Some tyv) def in
  let* defv = eval_checked c def' tyv in
  let c' = Check.define x Quantity.Many tyv defv c in
  let* body' = elab c' ~expected body in
  Ok (Term.Let (x, ty', def', body'))

(** One surface declaration, elaborated against the globals built so far.
    A def carries a body and an axiom does not (R-Q3);  the disclosure
    ledger classifies the axiom in lib/link.ml, so the two surface forms
    of the closed grammar of SPEC.md section 2 reach all four global
    kinds.  kanon c418062 surface/elab.ml:908-923. *)
let decl_of ?(budget : Budget.t = Budget.unlimited) (globals : Global.t)
    (d : Parser.decl) : (Check.decl, Error.t) result =
  let c : Check.ctx = Check.make globals budget in
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
      let* tyv = eval_type c ty' in
      let* body' = elab c ~expected:(Some tyv) body in
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
      let* kd = decl_of ~budget g d in
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
