-- a definition that reads a postulate.  two is believed and natAdd is a
-- native primitive of lib/prim.ml.
axiom two : Nat
def four : Nat := natAdd two two
