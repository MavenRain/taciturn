-- a public result from a W argument outside prove.  The file marks the
-- third binder of verifyRaw w, the ledger of SPEC.md section 6 stamps
-- that position many, and the disclosed mark is the one the call reads,
-- so the witness binder reaches a many stamped output position.
-- Error.Quantity refuses.
axiom Circuit : Type 0
axiom Public : Type 0
axiom Proof : (R : Circuit) -> (x : Public) -> Type 0
axiom verifyRaw : (R : Circuit) -> (x : Public) -> (w v : Proof R x) -> Nat
def leak : (R : Circuit) -> (x : Public) -> (w v : Proof R x) -> Nat := fun (R : Circuit) (x : Public) (w v : Proof R x) => verifyRaw R x v
