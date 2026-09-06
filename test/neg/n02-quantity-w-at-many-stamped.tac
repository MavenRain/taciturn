-- a W occurrence at a Many stamped point.  Both arguments of natAdd are
-- many stamped, so the witness binder does not read there.
-- Error.Quantity refuses.
def leak : (w s : Nat) -> Nat := fun (w s : Nat) => natAdd s s
