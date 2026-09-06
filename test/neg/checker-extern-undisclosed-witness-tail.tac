-- The tail of a declared function type can also hide a witness binder.
def Tail : Type 0 := (w x : Nat) -> Nat
axiom hidden : Nat -> Tail
def leak : (w secret : Nat) -> Nat := fun (w secret : Nat) => hidden 0 secret
