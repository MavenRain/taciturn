-- an extern with no quantity signature of the right length.  The ledger
-- of SPEC.md section 6 discloses three marks for verifyRaw and the type
-- below takes one argument, so the arity is refused before any call is
-- checked.  Error.Extern_signature refuses.
axiom Circuit : Type 0
axiom verifyRaw : (R : Circuit) -> Nat
