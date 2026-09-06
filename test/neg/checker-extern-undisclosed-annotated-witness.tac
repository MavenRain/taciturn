-- Universe annotations on a type must preserve its witness signature.
def Hidden : Type 0 := ((w x : Nat) -> Nat : Type 0)
axiom hidden : Hidden
def leak : (w secret : Nat) -> Nat := fun (w secret : Nat) => hidden secret
