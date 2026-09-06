(** The M0 driver.  Stage A answers one verb, spec-count, and names the
    stage of every other verb of M0-PLAN section 7.  A verb that is not
    in the table prints one usage line.

    The argument walk goes through [Arg], which reads the command line
    itself, so this file needs no indexed access to the argument vector.
    [run] leaves through [exit] on every path, so the two lines after
    [Arg.parse] run only when the command line carries no verb at all. *)

open Taciturn_kernel

let usage : string = "usage: taciturn spec-count"

(** The seven verbs that M0-PLAN section 7 declares and Stage A does not
    answer, each with the stage that lands it.  The check and the axiom
    ledger want the kernel of Stage B;  the row lowering, the digest and
    the representation check want the backend of Stage C;  the encoder
    and the witness writer want the module writer of Stage D. *)
let stage_of (verb : string) : string option =
  List.assoc_opt verb
    [
      ("check", "Stage B");
      ("axioms", "Stage B");
      ("rows", "Stage C");
      ("digest", "Stage C");
      ("repr-conform", "Stage C");
      ("emit", "Stage D");
      ("witness", "Stage D");
    ]

(* 64 is EX_USAGE, the value the shell gates read *)
let bad (line : string) : unit =
  prerr_endline line;
  exit 64

let later (verb : string) (stage : string) : unit =
  bad (Printf.sprintf "taciturn: %s arrives at %s" verb stage)

let unknown (verb : string) : unit =
  bad (Printf.sprintf "%s.  %s is not a taciturn command" usage verb)

let spec_count () : unit =
  print_string (Spec_count.print ());
  exit 0

let run (verb : string) : unit =
  if String.equal verb "spec-count" then spec_count ()
  else
    stage_of verb
    |> Option.fold
         ~none:(fun () -> unknown verb)
         ~some:(fun (stage : string) () -> later verb stage)
    |> fun k -> k ()

let () =
  Arg.parse [] run usage;
  bad usage
