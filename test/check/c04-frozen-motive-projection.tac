-- A stuck first projection sits inside the fibre of a second pair, so the
-- frozen elimination the fibre holds reads its motive back one binder in.
axiom Use : (0 A : Type 0) -> (a : A) -> Type 0
def f : (0 A : Type 0) -> (q : A * Nat) -> (p : (x : Nat) * Use A q.1) -> Use A q.1 :=
  fun (0 A : Type 0) (q : A * Nat) (p : (x : Nat) * Use A q.1) => p.2
