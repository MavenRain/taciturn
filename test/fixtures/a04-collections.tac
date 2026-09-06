-- the three bracketed lists, including the width zero form
def t : Type 0 := tuple (Nat, Bool, Nat)
def s : Type 0 := sum (Nat, Bool)
def p : Type 0 := prod (Nat, Bool)
def empty : Type 0 := sum ()
