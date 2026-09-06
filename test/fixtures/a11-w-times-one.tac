-- SA-M1:  one witness binder and one linear binder, so the mark product
-- of this file is w and the mul table has a printed reader.  The zk
-- attribute of D-M0-3 rides the same declaration.
zk def commit : (w s : Field p) -> (1 r : Field p) -> Field p := fun (w s : Field p) (1 r : Field p) => add s r
