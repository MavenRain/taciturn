-- Replacing p changes the meaning of the already checked body of stored.
axiom P : Prop
axiom p : P
def stored : P := p
axiom p : Nat
def impossible : P := stored
