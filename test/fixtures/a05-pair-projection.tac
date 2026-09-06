-- the pair and its two leg addresses;  projection binds tighter than
-- application
def first : Nat := (a, b).1
def second : Nat := (a, b).2
def applied : Nat := f (a, b).1
