(* carried from kanon c418062 lib/quantity.ml, delta: extracted intervals and separate witness stamps from linear multiplicity *)
(** A witness position is readable by W binders but may duplicate its
    argument. Keep the occurrence stamp separate from the usage demand. *)
type count = Zero | One | Many
type mode = { stamp : Quantity.t; demand : count }

let demand (q : Quantity.t) : count =
  match q with
  | Quantity.Zero -> Zero
  | Quantity.One -> One
  | Quantity.W | Quantity.Many -> Many

let mode (q : Quantity.t) : mode =
  { stamp = q; demand = if Quantity.equal q Quantity.Zero then Zero else One }

let erased (m : mode) : bool = Quantity.equal m.stamp Quantity.Zero
let runtime (m : mode) : mode = mode m.stamp

let mul (a : count) (b : count) : count =
  match a, b with
  | Zero, (Zero | One | Many) | (One | Many), Zero -> Zero
  | One, One -> One
  | One, Many | Many, (One | Many) -> Many

let multiply (m : mode) (q : Quantity.t) : mode =
  { stamp = Quantity.mul m.stamp q; demand = mul m.demand (demand q) }

let add (a : count) (b : count) : count =
  match a, b with
  | Zero, (Zero | One | Many) -> b
  | (One | Many), Zero -> a
  | (One | Many), (One | Many) -> Many

let rank (q : count) : int = match q with Zero -> 0 | One -> 1 | Many -> 2
let minimum (a : count) (b : count) : count = if rank a <= rank b then a else b
let maximum (a : count) (b : count) : count = if rank a >= rank b then a else b
let equal (a : count) (b : count) : bool = Int.equal (rank a) (rank b)

module Uses = Map.Make (Int)
type interval = count * count
(** Returning paths discharge exact-use obligations. Reads also record
    paths that cannot return, on which duplication must still fail. *)
type usage = { paths : interval Uses.t option; reads : interval Uses.t }

let empty : usage = { paths = Some Uses.empty; reads = Uses.empty }
let unreachable : usage = { paths = None; reads = Uses.empty }
let interval (level : int) (uses : interval Uses.t) : interval =
  Option.value (Uses.find_opt level uses) ~default:(Zero, Zero)

let occurrence (level : int) (m : mode) : usage =
  let reads = Uses.singleton level (m.demand, m.demand) in
  { paths = Some reads; reads }

let combine (f : count -> count -> count) (g : count -> count -> count)
    (a : interval Uses.t) (b : interval Uses.t) : interval Uses.t =
  Uses.merge (fun _level x y ->
    let lo, hi = Option.value x ~default:(Zero, Zero) in
    let lo', hi' = Option.value y ~default:(Zero, Zero) in
    Some (f lo lo', g hi hi')) a b

let sequence (a : usage) (b : usage) : usage =
  { paths = Option.bind a.paths (fun x -> Option.map (combine add add x) b.paths);
    reads = combine add add a.reads b.reads }

let alternative (a : usage) (b : usage) : usage =
  let join (x : interval Uses.t) : interval Uses.t option =
    Option.fold ~none:(Some x)
      ~some:(fun y -> Some (combine minimum maximum x y)) b.paths in
  { paths = Option.fold ~none:b.paths ~some:join a.paths;
    reads = combine maximum maximum a.reads b.reads }

let scale_range ((lo, hi) : interval) (uses : usage) : usage =
  let scale_map = Uses.map (fun (a, b) -> mul lo a, mul hi b) in
  { paths = Option.map scale_map uses.paths; reads = scale_map uses.reads }

let scale (m : mode) (uses : usage) : usage =
  if erased m then empty else scale_range (m.demand, m.demand) uses

let get (level : int) (uses : usage) : interval =
  let _lo, hi = interval level uses.reads in
  Option.fold ~none:(One, maximum One hi)
    ~some:(fun paths -> let lo, path_hi = interval level paths in lo, maximum path_hi hi)
    uses.paths

let remove (level : int) (uses : usage) : usage =
  { paths = Option.map (Uses.remove level) uses.paths; reads = Uses.remove level uses.reads }

let exactly_once (level : int) (uses : usage) : bool =
  let lo, hi = get level uses in equal lo One && equal hi One
let used (level : int) (uses : usage) : bool =
  let _lo, hi = interval level uses.reads in not (equal hi Zero)
let at_most_once (level : int) (uses : usage) : bool =
  let _lo, hi = get level uses in not (equal hi Many)

(** Allocating a closure returns even if invoking it cannot return.
    Retain dependencies from both returning and nonreturning paths. *)
let captures (uses : usage) : usage =
  let paths = Option.fold ~none:uses.reads
    ~some:(fun paths -> combine (fun lo _seen -> lo) maximum paths uses.reads) uses.paths in
  { paths = Some paths; reads = uses.reads }
