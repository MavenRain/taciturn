-- the one declassifier.  prove carries a W stamped position in the
-- disclosure ledger of SPEC.md section 6, so a witness binder reaches it
-- and its public result is read at a runtime mode.  No other head does.
axiom Circuit : Type 0
axiom Public : Type 0
axiom Witness : Type 0
axiom Proof : (R : Circuit) -> (x : Public) -> Type 0
axiom prove : (R : Circuit) -> (x : Public) -> (w wit : Witness) -> Proof R x
def declassified : (R : Circuit) -> (x : Public) -> (w wit : Witness) -> Proof R x := fun (R : Circuit) (x : Public) (w wit : Witness) => prove R x wit
