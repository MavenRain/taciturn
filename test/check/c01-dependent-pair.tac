-- The fibre is instantiated at the erased first component.
def packed : (0 A : Type 0) * A := ((x : Nat) -> Nat, fun (x : Nat) => x)
def result : Nat := packed.2 42
def unpack : (p : (0 A : Type 0) * A) -> p.1 :=
  fun (p : (0 A : Type 0) * A) => p.2
