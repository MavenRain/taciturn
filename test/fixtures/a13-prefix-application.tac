-- Prefix forms in function position retain their argument boundary.
def inj_app : T := (inj 0 of 1 f) x
def absurd_app : T := (absurd f) x
def inj_chain : T := (inj 0 of 1 f) x y
def absurd_chain : T := (absurd f) x y
