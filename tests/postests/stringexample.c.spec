string_succ ::
  forall    [A0; A1; A2]
  arg      (s: ref (A1, 4))
  ret      ref (A2, 0)
  store_in  [A1 |-> 0: ref (A1, 0), 4: ref (A2, 0);
             A2 |-> 0: int (4, true), 4: ref (A0, 0);
             A0 |-> 0[1]: int (1, true)]
  store_out [A1 |-> 0: ref (A1, 0), 4: ref (A2, 0);
             A2 |-> 0: int (4, true), 4: ref (A0, 0);
             A0 |-> 0[1]: int (1, true)]