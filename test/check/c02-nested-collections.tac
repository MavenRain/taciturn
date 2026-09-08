def Choice : Type 0 := sum (Nat, Nat * Nat)
def left : Choice := inj 0 of 2 3
def right : Choice := inj 1 of 2 (5, 7)
def packed : prod (Nat * Nat, Choice) := tuple ((11, 13), right)
def result : Nat := packed.0.2
