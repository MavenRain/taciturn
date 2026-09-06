# dev/strip-ocaml.awk
# Blanks every doc comment, every ordinary comment and every string
# literal of an OCaml source, one space per removed character, so the
# output holds the same number of lines and the same column positions as
# the input.  SB-G10 matches the banned token pattern over the output, so
# a hit is a token in CODE and prose can never make the gate red.
#
# Strings inside comments still own their delimiters.  Ordinary strings,
# quoted strings and nested comments carry their state across lines.
# A character literal is skipped whole, so 'x' and '\n' hide nothing.
# An unfinished comment or string fails the scanner instead of hiding code.

BEGIN { depth = 0; instr = 0; quoted = "" }

function blanks(count, result) {
  result = ""
  while (count > 0) { result = result " "; count = count - 1 }
  return result
}

{
  line = $0
  n = length(line)
  out = ""
  i = 1
  while (i <= n) {
    c = substr(line, i, 1)
    d = substr(line, i, 2)
    if (quoted != "") {
      if (substr(line, i, length(quoted)) == quoted) {
        out = out blanks(length(quoted)); i = i + length(quoted); quoted = ""
      } else { out = out " "; i = i + 1 }
      continue
    }
    if (instr == 1) {
      if (c == "\\") {
        size = (i < n ? 2 : 1)
        out = out blanks(size); i = i + size; continue
      }
      if (c == "\"") { instr = 0; out = out " "; i = i + 1; continue }
      out = out " "; i = i + 1; continue
    }
    if (c == "'") {
      prev = " "
      if (i > 1) { prev = substr(line, i - 1, 1) }
      if (prev !~ /[A-Za-z0-9_']/) {
        if (substr(line, i + 2, 1) == "'") { out = out "   "; i = i + 3; continue }
        if (substr(line, i + 1, 1) == "\\" && substr(line, i + 3, 1) == "'") {
          out = out "    "; i = i + 4; continue
        }
      }
    }
    if (c == "{") {
      rest = substr(line, i)
      if (match(rest, /^\{([a-z_]*|%%?[A-Za-z_][A-Za-z0-9_'.]*([ \t]+[a-z_]*)?)\|/)) {
        opener = substr(rest, 1, RLENGTH)
        delimiter = substr(opener, 2, length(opener) - 2)
        if (substr(delimiter, 1, 1) == "%") {
          if (delimiter ~ /[ \t]/) { sub(/^.*[ \t]/, "", delimiter) } else { delimiter = "" }
        }
        quoted = "|" delimiter "}"
        out = out blanks(length(opener)); i = i + length(opener); continue
      }
    }
    if (c == "\"") { instr = 1; out = out " "; i = i + 1; continue }
    if (d == "(*") { depth = depth + 1; out = out "  "; i = i + 2; continue }
    if (depth > 0) {
      if (d == "*)") { depth = depth - 1; out = out "  "; i = i + 2; continue }
      out = out " "; i = i + 1; continue
    }
    out = out c
    i = i + 1
  }
  print out
}

END {
  if (depth != 0 || instr != 0 || quoted != "") {
    print "strip-ocaml: unfinished comment or string" > "/dev/stderr"
    exit 1
  }
}
