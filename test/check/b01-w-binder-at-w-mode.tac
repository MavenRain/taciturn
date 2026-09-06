-- a W binder read at mode W.  The argument of useW sits at a W stamped
-- point, so the witness mark reads there and the occurrence rule of
-- SPEC.md section 3.1 admits it.
def useW : (w s : Nat) -> Nat := fun (w s : Nat) => 0
def passW : (w s : Nat) -> Nat := fun (w s : Nat) => useW s
