def Empty : Type 0 := sum ()
def Unit : Type 0 := prod ()
def unit : Unit := tuple ()
def eliminate : (e : Empty) -> Nat := fun (e : Empty) => absurd e
