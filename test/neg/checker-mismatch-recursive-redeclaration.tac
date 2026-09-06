-- A replacement must not turn an earlier reference into a recursive body.
def value : Nat := 0
def value : Nat := value
