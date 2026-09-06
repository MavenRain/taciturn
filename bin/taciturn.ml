(** The M0 driver.  Stage A answered one verb, spec-count, and named the
    stage of every other verb of M0-PLAN section 7.  Stage B lands check
    and axioms, which need the checker and nothing else;  the row
    lowering, the digest and the representation check arrive at Stage C
    and the encoder and the witness writer at Stage D.

    Exit codes.  0 is a file that checks, 1 is a file that does not and
    64 is a usage error or a file the driver cannot see.  A check failure
    writes one [Error.to_string] line to stderr and nothing to stdout, so
    a caller reads stdout as the answer alone.

    The argument walk goes through [Arg], which reads the command line
    itself, so this file needs no indexed access to the argument vector
    and spells no array combinator.  The anonymous arguments are
    collected in declaration order and the verb is dispatched once, after
    the walk ends.

    Every kernel entry point takes an optional budget that defaults to
    [Budget.unlimited] and the kernel reads no clock, so a driver may cap
    a check and the check itself stays a pure function of its input. *)

open Taciturn_kernel

let usage : string =
  "usage: taciturn check FILE | axioms FILE | spec-count"

(** The five verbs that M0-PLAN section 7 declares and Stage B does not
    answer, each with the stage that lands it. *)
let stage_of (verb : string) : string option =
  List.assoc_opt verb
    [
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

(** The whole repository holds one catch site, in test/main.ml, so this
    file reaches [In_channel] behind a [Sys.file_exists] guard and reports
    a path it cannot see as a usage error.  A path that disappears
    between the guard and the read leaves the process, which is loud, and
    never a wrong answer. *)
let read_file (path : string) : string =
  if Sys.file_exists path then
    In_channel.with_open_bin path In_channel.input_all
  else (
    prerr_endline (Printf.sprintf "taciturn: cannot read %s" path);
    exit 64)

(** The file, parsed, elaborated and checked against [Global.initial].  A
    refusal writes the error line of the pin's shape, with the [Error]
    constructor named by [Error.to_string], and leaves with 1. *)
let checked (path : string) : (string * Global.entry) list =
  Taciturn_surface.Elab.check (read_file path)
  |> Result.fold
       ~ok:(fun (rows : (string * Global.entry) list) -> rows)
       ~error:(fun (e : Error.t) ->
         prerr_endline (Error.to_string e);
         exit 1)

(** "check FILE".  The file checks or it does not, and stdout stays
    empty either way, so a gate reads the exit code. *)
let run_check (path : string) : unit =
  let (_rows : (string * Global.entry) list) = checked path in
  exit 0

(** "axioms FILE".  One row per axiom and per extern of the FILE, in
    declaration order, with its actual checked type and any ledger text. *)
let run_axioms (path : string) : unit =
  List.iter print_endline
    (Taciturn_surface.Elab.disclosure_lines (checked path));
  exit 0

(** The argument order is fixed, so any other shape is a usage error. *)
let dispatch_file (verb : string) (run : string -> unit) (args : string list) :
    unit =
  match args with
  | path :: _rest -> run path
  | [] -> bad (Printf.sprintf "%s.  %s wants a file" usage verb)

let dispatch (verb : string) (args : string list) : unit =
  match verb with
  | "spec-count" -> spec_count ()
  | "check" -> dispatch_file verb run_check args
  | "axioms" -> dispatch_file verb run_axioms args
  | _other ->
      stage_of verb
      |> Option.fold
           ~none:(fun () -> unknown verb)
           ~some:(fun (stage : string) () -> later verb stage)
      |> fun (k : unit -> unit) -> k ()

(** The anonymous arguments, in the order [Arg] hands them over.  The
    cell is an [Atomic], not a [ref] cell:  the house rules of the Stage
    0 brief ban the mutable keywords, and the walk needs one write per
    argument and one read after it. *)
let seen : string list Atomic.t = Atomic.make []

let collect (a : string) : unit = Atomic.set seen (a :: Atomic.get seen)

let () =
  Arg.parse [] collect usage;
  match List.rev (Atomic.get seen) with
  | verb :: args -> dispatch verb args
  | [] -> bad usage
