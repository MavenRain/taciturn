-- A disclosed signature reads through both an alias and its annotation.
axiom Circuit : Type 0
axiom Public : Type 0
axiom Witness : Type 0
axiom Proof : (R : Circuit) -> (x : Public) -> Type 0
def Prover : Type 0 := ((R : Circuit) -> (x : Public) -> (w wit : Witness) -> Proof R x : Type 0)
axiom prove : Prover
def call : (R : Circuit) -> (x : Public) -> (w wit : Witness) -> Proof R x := fun (R : Circuit) (x : Public) (w wit : Witness) => prove R x wit
