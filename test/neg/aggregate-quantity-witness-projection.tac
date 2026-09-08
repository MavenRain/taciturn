def leak : (p : (w x : Nat) * Nat) -> Nat :=
  fun (p : (w x : Nat) * Nat) => p.1
