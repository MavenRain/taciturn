(** The sum of SPEC.md section 3.2, Stage B brief 3.5.  The sum counts
    usage and it is NOT the occurrence rule:  the occurrence rule of
    section 3.1 lives at the [readable] site of lib/check.ml and refuses
    with [Error.Quantity], and this file refuses with [Error.Usage], so a
    gate line names which rule refused.

    Each occurrence of a binder contributes the mark the binder was
    declared at, and the occurrences are added with the table of SPEC.md
    section 3.2.  The counted sum must then be admissible in the declared
    mark:  in {Zero} at a Zero binder, in {Zero, W} at a W binder, in
    {Zero, One} at a One binder and anywhere at a Many binder.  [W] plus
    [W] is [W], so a witness binder that is read twice stays admissible,
    and [One] plus [One] is [Many], so a linear binder that is read twice
    does not.

    The walk visits every section of a term, so an inner lambda is
    counted beside the lambda chain of the declaration.  It does not
    descend into the payload of a shape, which is a type and carries no
    usage obligation at M0.  No shape name appears here:  the binder
    count of a former goes through [Rules.as_vpi] and an address through
    [Term.as_apt], so the R0-AUDIT leg stays clean over this file. *)

let ( let* ) = Result.bind

(** The table of SPEC.md section 3.2, sixteen arms and no wildcard.
    [Zero] is the unit on both sides, which is seven arms.  [W] carries
    over itself, which is one.  Every remaining pair is [Many], which is
    eight. *)
let add (a : Quantity.t) (b : Quantity.t) : Quantity.t =
  match (a, b) with
  | Quantity.Zero, Quantity.Zero -> Quantity.Zero
  | Quantity.Zero, Quantity.W -> Quantity.W
  | Quantity.Zero, Quantity.One -> Quantity.One
  | Quantity.Zero, Quantity.Many -> Quantity.Many
  | Quantity.W, Quantity.Zero -> Quantity.W
  | Quantity.One, Quantity.Zero -> Quantity.One
  | Quantity.Many, Quantity.Zero -> Quantity.Many
  | Quantity.W, Quantity.W -> Quantity.W
  | Quantity.W, Quantity.One -> Quantity.Many
  | Quantity.W, Quantity.Many -> Quantity.Many
  | Quantity.One, Quantity.W -> Quantity.Many
  | Quantity.Many, Quantity.W -> Quantity.Many
  | Quantity.One, Quantity.One -> Quantity.Many
  | Quantity.One, Quantity.Many -> Quantity.Many
  | Quantity.Many, Quantity.One -> Quantity.Many
  | Quantity.Many, Quantity.Many -> Quantity.Many

(** The admissible sums of one declared mark, SPEC.md section 3.2. *)
let admissible (declared : Quantity.t) (sum : Quantity.t) : bool =
  match (declared, sum) with
  | Quantity.Zero, Quantity.Zero -> true
  | Quantity.Zero, Quantity.W -> false
  | Quantity.Zero, Quantity.One -> false
  | Quantity.Zero, Quantity.Many -> false
  | Quantity.W, Quantity.Zero -> true
  | Quantity.W, Quantity.W -> true
  | Quantity.W, Quantity.One -> false
  | Quantity.W, Quantity.Many -> false
  | Quantity.One, Quantity.Zero -> true
  | Quantity.One, Quantity.W -> false
  | Quantity.One, Quantity.One -> true
  | Quantity.One, Quantity.Many -> false
  | Quantity.Many, Quantity.Zero -> true
  | Quantity.Many, Quantity.W -> true
  | Quantity.Many, Quantity.One -> true
  | Quantity.Many, Quantity.Many -> true

(** The binders a former introduces over its codomain:  the point shape
    binds once and every other shape binds none. *)
let former_binders (s : Term.t Shape.t) : int =
  Rules.as_vpi s
  |> Option.fold ~none:0
       ~some:(fun ((_q : Quantity.t), (_x : string), (_d : Term.t)) -> 1)

let total (ns : int list) : int = List.fold_left ( + ) 0 ns

(** The occurrences of the local at de Bruijn index [ix] in a term. *)
let rec count (ix : int) (t : Term.t) : int =
  match t with
  | Term.Var k -> if Int.equal k ix then 1 else 0
  | Term.Univ _ -> 0
  | Term.Global _ -> 0
  | Term.Lit _ -> 0
  | Term.Auto -> 0
  | Term.Lan (s, cod) -> count (ix + former_binders s) cod
  | Term.Ran (s, cod) -> count (ix + former_binders s) cod
  | Term.In (_s, addr, args) ->
      count_addr ix addr + total (List.map (count ix) args)
  | Term.Sec (_s, legs) -> total (List.map (count_leg ix) legs)
  | Term.Out (_s, addr, scrut) -> count_addr ix addr + count ix scrut
  | Term.Let (_x, ty, def, body) ->
      count ix ty + count ix def + count (ix + 1) body
  | Term.Ann (a, ty) -> count ix a + count ix ty
  | Term.Elim e -> count_elim ix e

and count_addr (ix : int) (a : Term.addr) : int =
  Term.as_apt a
  |> Option.fold ~none:0
       ~some:(fun ((_q : Quantity.t), (arg : Term.t)) -> count ix arg)

and count_leg (ix : int) (l : Term.leg) : int =
  count (ix + List.length l.Term.l_binders) l.Term.l_body

and count_elim (ix : int) (e : Term.elim) : int =
  count ix e.Term.e_scrut
  + (e.Term.e_motive
    |> Option.fold ~none:0 ~some:(fun (m : Term.motive) ->
           count (ix + List.length m.Term.m_idx + 1) m.Term.m_body))
  + total
      (List.map
         (fun ((a : Term.addr), (l : Term.leg)) ->
           count_addr ix a + count_leg ix l)
         e.Term.e_branches)

let refusal (x : string) (q : Quantity.t) (sum : Quantity.t) (n : int) : Error.t =
  Error.Usage
    (Printf.sprintf
       "the binder %s is declared %s and is read %d times, which sums to %s and is not \
        admissible in %s"
       x (Quantity.to_string q) n (Quantity.to_string sum) (Quantity.to_string q))

(** The sum of [n] occurrences of a binder declared at [q]. *)
let sum_of (q : Quantity.t) (n : int) : Quantity.t =
  List.fold_left
    (fun (acc : Quantity.t) (_i : int) -> add acc q)
    Quantity.Zero
    (List.init (Int.max n 0) Fun.id)

let binder_ok (body : Term.t) (ix : int) ((q : Quantity.t), (x : string)) :
    (unit, Error.t) result =
  let n : int = count ix body in
  let s : Quantity.t = sum_of q n in
  if admissible q s then Ok () else Error (refusal x q s n)

(** The binders of one leg with the de Bruijn index each one carries
    inside the leg body:  [l_binders] is outermost first, so the last
    binder is index zero. *)
let indexed (l : Term.leg) : (int * (Quantity.t * string)) list =
  let n : int = List.length l.Term.l_binders in
  List.mapi
    (fun (k : int) ((q : Quantity.t), (x : string)) -> (n - 1 - k, (q, x)))
    l.Term.l_binders

let fold_results (xs : (unit, Error.t) result list) : (unit, Error.t) result =
  List.fold_left
    (fun (acc : (unit, Error.t) result) (r : (unit, Error.t) result) ->
      Result.bind acc (fun () -> r))
    (Ok ())
    xs

(** Every section of a term, checked.  The walk is the same shape as
    [count] and it returns at the first refusal. *)
let rec walk (t : Term.t) : (unit, Error.t) result =
  match t with
  | Term.Var _ | Term.Univ _ | Term.Global _ | Term.Lit _ | Term.Auto -> Ok ()
  | Term.Lan (_s, cod) -> walk cod
  | Term.Ran (_s, cod) -> walk cod
  | Term.In (_s, addr, args) ->
      let* () = walk_addr addr in
      fold_results (List.map walk args)
  | Term.Sec (_s, legs) -> fold_results (List.map walk_leg legs)
  | Term.Out (_s, addr, scrut) ->
      let* () = walk_addr addr in
      walk scrut
  | Term.Let (_x, ty, def, body) ->
      let* () = walk ty in
      let* () = walk def in
      walk body
  | Term.Ann (a, ty) ->
      let* () = walk a in
      walk ty
  | Term.Elim e ->
      let* () = walk e.Term.e_scrut in
      fold_results
        (List.map
           (fun ((a : Term.addr), (l : Term.leg)) ->
             Result.bind (walk_addr a) (fun () -> walk_leg l))
           e.Term.e_branches)

and walk_addr (a : Term.addr) : (unit, Error.t) result =
  Term.as_apt a
  |> Option.fold ~none:(Ok ())
       ~some:(fun ((_q : Quantity.t), (arg : Term.t)) -> walk arg)

and walk_leg (l : Term.leg) : (unit, Error.t) result =
  let* () =
    fold_results
      (List.map
         (fun ((ix : int), (b : Quantity.t * string)) ->
           binder_ok l.Term.l_body ix b)
         (indexed l))
  in
  walk l.Term.l_body

(** The entry point lib/check.ml calls once per definition body. *)
let body (t : Term.t) : (unit, Error.t) result = walk t
