(** SHA-256 through /usr/bin/shasum, the provisional M0 hash choice.
    Cleanup is attempted on every path.  A hash error has precedence over a cleanup error.
    Arguments are passed directly, without a shell.  The child process
    gets the explicit environment PATH=/usr/bin:/bin. *)
type error = Io of string | Process of Unix.process_status | Output
val error_string : error -> string
val bytes : string -> (Taciturn_zk.Digest.sha256, error) result
val circuit : Taciturn_zk.Digest.context -> Taciturn_zk.Rows.circuit ->
  (Taciturn_zk.Digest.sha256, error) result
