axiom P : Prop
axiom f : Nat -> Nat
axiom F : Nat -> Type 0
def leak : (h : Nat -> Nat) -> (a : Nat) -> Type 0 := fun (h : P -> Nat) (a : P) => F (h a)
axiom x : leak f 0
def y : leak f 1 := x
