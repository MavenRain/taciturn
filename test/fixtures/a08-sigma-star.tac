-- the dependent pair type, right associative
def sigma : Type 0 := (x : Nat) * P x
def plain : Type 0 := Nat * Bool
def chain : Type 0 := (x : Nat) * (y : Nat) * Q x y
