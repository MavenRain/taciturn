-- A type alias must not hide a witness-taking foreign implementation.
def Hidden : Type 0 := (w x : Nat) -> Nat
axiom hidden : Hidden
def leak : (w secret : Nat) -> Nat := fun (w secret : Nat) => hidden secret
