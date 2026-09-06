-- an extern with its disclosure row.  Every position verifyRaw discloses
-- is many stamped, so its result leaves through a public output channel
-- and the call needs no declassifier.
axiom Circuit : Type 0
axiom Public : Type 0
axiom Proof : (R : Circuit) -> (x : Public) -> Type 0
axiom verifyRaw : (R : Circuit) -> (x : Public) -> (v : Proof R x) -> Nat
def verified : (R : Circuit) -> (x : Public) -> (v : Proof R x) -> Nat := fun (R : Circuit) (x : Public) (v : Proof R x) => verifyRaw R x v
