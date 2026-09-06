-- a W binder read at mode Zero.  A type is read at mode Zero, where
-- every mark reads, so the witness binder may appear in the codomain of
-- the arrow it binds.
axiom P : (n : Nat) -> Type 0
def wAtZero : Type 0 := (w s : Nat) -> P s
