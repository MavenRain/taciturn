-- the smallest declaration:  a dependent arrow and a lambda
def id : (x : Nat) -> Nat := fun (x : Nat) => x
def const : (x : Nat) -> (y : Nat) -> Nat := fun (x : Nat) (y : Nat) => x
