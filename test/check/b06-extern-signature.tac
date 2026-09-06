-- an extern with a full per-argument quantity signature.  select holds
-- three marks in the ledger of SPEC.md section 6 and the type below
-- takes three arguments, so the arity check of M0-PLAN section 4 delta 3
-- passes and the axioms verb prints the signature.
axiom Bit : Type 0
axiom Field : Type 0
axiom select : (w b : Bit) -> (w x : Field) -> (w y : Field) -> Field
