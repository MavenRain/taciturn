-- An alias must not hide a public extern's disclosed argument mark.
axiom Circuit : Type 0
axiom Public : Type 0
axiom Proof : (R : Circuit) -> (x : Public) -> Type 0
axiom verifyRaw : (R : Circuit) -> (x : Public) -> (w v : Proof R x) -> Nat
def alias : (R : Circuit) -> (x : Public) -> (w v : Proof R x) -> Nat := verifyRaw
def leak : (R : Circuit) -> (x : Public) -> (w v : Proof R x) -> Nat := fun (R : Circuit) (x : Public) (w v : Proof R x) => alias R x v
