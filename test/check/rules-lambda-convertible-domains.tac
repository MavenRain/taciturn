def Alias : Type 0 := Nat
def identity : Nat -> Nat := fun (x : Alias) => x
def dependent : (A : Type 0) -> (x : A) -> A := fun (A : Type 0) (x : A) => x
