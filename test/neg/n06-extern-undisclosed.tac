-- an extern with no disclosure row.  A postulate that takes a witness
-- argument names a foreign implementation that touches witness data, and
-- the ledger of SPEC.md section 6 holds no row for this name, so it
-- refuses to link.  Error.Extern_undisclosed refuses.
axiom fieldNeg : (w a : Nat) -> Nat
