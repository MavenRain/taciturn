(** The R0 counts, printed by [taciturn spec-count] and pinned in the
    "## R0 counts" block of SPEC.md.  dev/r0-count.sh diffs the two, so a
    count that grows past the spec fails the R0-COUNT gate leg.

    Every printed number is [List.length] of the list printed after it.
    A literal integer in a printed count is a finding.  The shape list
    comes from [Shape], so a sixth shape moves its own count with no edit
    here.

    Stage A moves no count:  the block is kanon's block at de40d65, line
    by line, because the witness quantity adds a mark and adds no former,
    no schema constructor and no shape.  The former list, the schema list
    and the rule ledger are written out here because lib/term.ml and
    lib/rules.ml arrive at Stage B;  each one becomes a read of that
    module when it lands, and the printed text does not move.  D-M0-4's
    ninth line, "global kinds 4: Def Axiom Prim Extern", arrives at Stage
    B with the Extern entry and is not printed here. *)

let formers : string list = [ "Lan"; "Ran" ]
let schema : string list = [ "In"; "Elim"; "Sec"; "Out" ]

(** The shapes M0 admits, as a filter of [Shape.declared], so the printed
    order is the order of the shape sum and a shape that leaves the sum
    leaves this list with it. *)
let admits (name : string) : bool =
  List.exists (String.equal name) [ "SPi"; "SColl"; "SMu" ]

let admitted : string list = List.filter admits Shape.declared

let rules_declared : string list =
  [ "proof-irrelevance"; "subsingleton-large-elimination"; "literal-fast-path" ]

let rules_present : string list = rules_declared

(* total lookup;  the house rules ban the partial indexing combinators *)
let rec at (n : int) (xs : string list) : string option =
  match xs with
  | [] -> None
  | x :: rest -> if Int.equal n 0 then Some x else at (n - 1) rest

let pick (n : int) (xs : string list) : string = at n xs |> Option.value ~default:"?"
let lan : string = pick 0 formers
let ran : string = pick 1 formers

(** One admitted shape and the two eta answers over it, right former
    first.  The pack that owns the answers is lib/rules.ml at Stage B and
    this table becomes a read of it then. *)
type eta_row = {
  eta_ran : bool;
  eta_lan : bool;
}

let eta_table : (string * eta_row) list =
  [
    ("SPi", { eta_ran = true; eta_lan = true });
    ("SColl", { eta_ran = true; eta_lan = false });
    ("SMu", { eta_ran = false; eta_lan = false });
  ]

(** The derived eta table:  a row exists where the shape has a unique
    introduction address and the structural expansion ends.  The two
    lists partition the six former and shape pairs of the admitted
    shapes, right former first within each shape. *)
let eta_of (keep : bool) : string list =
  List.concat_map
    (fun ((n : string), (e : eta_row)) ->
      List.filter_map
        (fun ((former : string), (has : bool)) ->
          if Bool.equal has keep then Some (former ^ "-" ^ n) else None)
        [ (ran, e.eta_ran); (lan, e.eta_lan) ])
    eta_table

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
    ]
