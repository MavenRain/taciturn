#!/opt/homebrew/bin/python3 -P
"""dev/spike-gates-mutate.py IN.r1cs IN.wtns OUT.r1cs OUT.wtns

Writes two negative-control copies for S0-G5, from the format spec of
dossier-toolchain sections 1 and 2 alone (little-endian, fixed widths):

  OUT.wtns: a copy of IN.wtns with one byte of the last witness value
  flipped (XOR 0xFF on the final byte of the file, the high-order byte of
  the last little-endian field element, since section 2 is the last
  section and its values are packed with no padding).

  OUT.r1cs: a copy of IN.r1cs with the two terms of one linear combination
  (the first one found with at least two terms) swapped, breaking the
  ascending-wire-id sort the reader must check.

Exits 0 on success with one evidence line, 2 on a usage or format error.
"""

import struct
import sys


def read_u32(buf, off):
    return struct.unpack_from("<I", buf, off)[0]


def read_u64(buf, off):
    return struct.unpack_from("<Q", buf, off)[0]


def sections(buf):
    off = 8  # magic (4) + version (4)
    n_sections = read_u32(buf, off)
    off += 4
    out = []
    for _ in range(n_sections):
        stype = read_u32(buf, off)
        ssize = read_u64(buf, off + 4)
        content_off = off + 12
        out.append((stype, content_off, ssize))
        off = content_off + ssize
    return out


def flip_wtns(in_path, out_path):
    with open(in_path, "rb") as f:
        buf = bytearray(f.read())
    if len(buf) == 0:
        return "wtns file empty"
    buf[-1] ^= 0xFF
    with open(out_path, "wb") as f:
        f.write(buf)
    return "flipped last byte of {0} bytes".format(len(buf))


def swap_r1cs_terms(in_path, out_path):
    with open(in_path, "rb") as f:
        buf = bytearray(f.read())
    secs = sections(buf)
    header = next((s for s in secs if s[0] == 1), None)
    constraints = next((s for s in secs if s[0] == 2), None)
    if header is None or constraints is None:
        return None
    fs = read_u32(buf, header[1])
    term_len = 4 + fs
    off = constraints[1]
    end = constraints[1] + constraints[2]
    while off < end:
        for _ in range(3):  # A, B, C in one constraint
            n_terms = read_u32(buf, off)
            terms_off = off + 4
            if n_terms >= 2:
                a0 = terms_off
                a1 = terms_off + term_len
                first = bytes(buf[a0:a0 + term_len])
                second = bytes(buf[a1:a1 + term_len])
                buf[a0:a0 + term_len] = second
                buf[a1:a1 + term_len] = first
                with open(out_path, "wb") as f:
                    f.write(buf)
                return "swapped 2 terms at offset {0}".format(a0)
            off = terms_off + n_terms * term_len
    return None


def main(argv):
    if len(argv) != 5:
        print("MUTATE-USAGE spike-gates-mutate.py IN.r1cs IN.wtns OUT.r1cs OUT.wtns")
        return 2
    in_r1cs, in_wtns, out_r1cs, out_wtns = argv[1:5]
    wtns_note = flip_wtns(in_wtns, out_wtns)
    r1cs_note = swap_r1cs_terms(in_r1cs, out_r1cs)
    if r1cs_note is None:
        print("MUTATE FAIL no linear combination with >=2 terms found")
        return 2
    print("MUTATE OK wtns={0} r1cs={1}".format(wtns_note, r1cs_note))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
