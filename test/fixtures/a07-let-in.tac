-- a local definition, whose body reaches as far right as it can
def l : Nat := let x : Nat := 3 in f x
def nested : Nat := let x : Nat := 3 in let y : Nat := x in f x y
