-- the sum of SPEC.md section 3.2, which is a well-formedness check and
-- not the occurrence rule.  The linear binder is read twice, One plus
-- One is Many at M0 counting, and Many is not admissible in One.
-- Error.Usage refuses, with its own constructor.
def dup : (1 r : Nat) -> Nat := fun (1 r : Nat) => natAdd r r
