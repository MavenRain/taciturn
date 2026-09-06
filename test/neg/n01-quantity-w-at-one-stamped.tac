-- a W occurrence at a One stamped point.  useOne marks its argument 1,
-- so the point is stamped One and the witness binder does not read
-- there.  Error.Quantity refuses.
axiom useOne : (1 r : Nat) -> Nat
def leak : (w s : Nat) -> Nat := fun (w s : Nat) => useOne s
