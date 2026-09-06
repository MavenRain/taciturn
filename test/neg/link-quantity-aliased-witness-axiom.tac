-- Neither type aliases nor function aliases may hide the witness input.
def Hidden : Type 0 := (w x : Nat) -> Nat
axiom verify_reflect : Hidden
def alias : Hidden := verify_reflect
def leak : (w x : Nat) -> Nat := fun (w x : Nat) => alias x
