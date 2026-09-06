-- the two axioms of M0-PLAN section 4 delta 3, declared together.  Both
-- hold an Axiom row in the ledger of SPEC.md section 6 and no file
-- defines either one.  The report also lists their three type postulates.
axiom Circuit : Type 0
axiom Public : Type 0
axiom Proof : (R : Circuit) -> (x : Public) -> Type 0
axiom sound : (R : Circuit) -> (x : Public) -> (v : Proof R x) -> Nat
axiom verify_reflect : (R : Circuit) -> (x : Public) -> (o : Nat) -> Proof R x
