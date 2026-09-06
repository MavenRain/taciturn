-- A ledger axiom must not acquire an undisclosed witness input.
axiom sound : (w x : Nat) -> Nat
def leak : (w x : Nat) -> Nat := fun (w x : Nat) => sound x
