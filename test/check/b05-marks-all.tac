-- the erased mark, the linear mark and the absent mark, which reads as
-- many.  Each binder is read the number of times its declared mark
-- admits under the sum of SPEC.md section 3.2.
def erasedFirst : (0 T : Type 0) -> (x : Nat) -> Nat := fun (0 T : Type 0) (x : Nat) => x
def linearOnce : (1 r : Nat) -> Nat := fun (1 r : Nat) => r
def manyTwice : (n : Nat) -> Nat := fun (n : Nat) => natAdd n n
