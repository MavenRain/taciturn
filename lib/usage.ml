(** The public witness-mark sum table of SPEC.md section 3.2.
    W addition is idempotent. Runtime path counts belong to Linear,
    whose multiplicities are independent of occurrence stamps. *)

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
  | Quantity.One, Quantity.Zero -> false
  | Quantity.One, Quantity.W -> false
  | Quantity.One, Quantity.One -> true
  | Quantity.One, Quantity.Many -> false
  | Quantity.Many, Quantity.Zero -> true
  | Quantity.Many, Quantity.W -> true
  | Quantity.Many, Quantity.One -> true
  | Quantity.Many, Quantity.Many -> true
