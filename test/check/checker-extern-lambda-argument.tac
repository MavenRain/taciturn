-- A disclosed argument uses its expected domain to check a lambda.
axiom Circuit : Type 0
axiom Public : Type 0
def Witness : Type 0 := Nat -> Nat
axiom Proof : (R : Circuit) -> (x : Public) -> Type 0
axiom prove : (R : Circuit) -> (x : Public) -> (w wit : Witness) -> Proof R x
def call : (R : Circuit) -> (x : Public) -> Proof R x := fun (R : Circuit) (x : Public) => prove R x (fun (n : Nat) => n)
