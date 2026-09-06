(** The R0 counts, printed by [taciturn spec-count] and pinned in the
    "## R0 counts" block of SPEC.md.  dev/r0-count.sh diffs the two, so a
    count that grows past the spec fails the R0-COUNT gate leg.

    Every printed number is [List.length] of the list printed after it.
    A literal integer in a printed count is a finding.

    Stage A wrote the former list, the schema list, the admitted shapes,
    the rule ledger and the eta table out here, because lib/term.ml and
    lib/rules.ml arrive at Stage B.  Stage B makes each one a read of the
    module that owns it, as the Stage A note promised, and the printed
    text does not move.  Two things follow.  A sixth shape, a third
    former or a fifth schema constructor moves its own count with no edit
    in this file.  No shape name is spelled here any more, so the
    R0-AUDIT leg passes over this file.

    Stage B also adds D-M0-4's ninth line, "global kinds 4: Def Axiom
    Prim Extern".  It reads [Global.kinds], whose companion
    [Global.kind_name] is total over the entry sum, so a fifth kind is a
    compile error at global.ml before it is a silent drift here.  The
    three pinned numbers do not move, so the milestone row is
    unaffected. *)

let formers : string list = Term.formers
let schema : string list = Term.schema

(** The shapes M0 admits are the shapes that carry a rule pack, read off
    [Rules.rules] itself, so a shape that gains or loses a pack moves
    this count with no edit here. *)
let admitted : string list = Rules.admitted

let rules_declared : string list = Rules.named_declared
let rules_present : string list = Rules.named_present

(* total lookup;  the house rules ban the partial indexing combinators *)
let rec at (n : int) (xs : string list) : string option =
  match xs with
  | [] -> None
  | x :: rest -> if Int.equal n 0 then Some x else at (n - 1) rest

let pick (n : int) (xs : string list) : string = at n xs |> Option.value ~default:"?"
let lan : string = pick 0 formers
let ran : string = pick 1 formers

(** The derived eta table:  a row exists where the shape has a unique
    introduction address and the structural expansion ends.  The two
    lists partition the former and shape pairs of the admitted shapes,
    right former first within each shape.  The answers come from the
    pack that owns them (lib/rules.ml [eta_table]). *)
let eta_of (keep : bool) : string list =
  List.concat_map
    (fun ((n : string), (e : Rules.eta_row)) ->
      List.filter_map
        (fun ((former : string), (has : bool)) ->
          if Bool.equal has keep then Some (former ^ "-" ^ n) else None)
        [ (ran, e.Rules.eta_ran); (lan, e.Rules.eta_lan) ])
    Rules.eta_table

let eta_rows : string list = eta_of true
let no_eta : string list = eta_of false

let row (label : string) (items : string list) : string =
  Printf.sprintf "%s %d: %s\n" label (List.length items) (String.concat " " items)

let print () : string =
  String.concat ""
    [
      row "formers" formers;
      row "schema constructors" schema;
      row "shapes declared" Shape.declared;
      row "shapes admitted" admitted;
      row "named rules declared" rules_declared;
      row "named rules present" rules_present;
      row "eta rows" eta_rows;
      row "no eta" no_eta;
      row "global kinds" Global.kinds;
    ]
