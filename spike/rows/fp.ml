(* fp.ml.  The BN254 scalar field of the brief section 2.  A value is 11
   limbs, least significant first, base 2^24, every limb inside
   [0, 2^24).  11 limbs hold 264 bits and p holds 254, so a sum or a
   doubled remainder never leaves the limbs.  fp.mli hides the type. *)

type t = int list

let limb_bits = 24
let base = 16777216
let limbs = 11

(* The byte width of one encoded element: fs in the r1cs header and n8 in
   the wtns header, both 32 (dossier-toolchain sections 1 and 2). *)
let width = 32

(* The limb split, and the only place a base appears: the low 24 bits are
   the digit and the rest is the carry.  A mask and a shift stand in the
   place of a bare modulo and a bare division against the limb base 2^24
   named just above, so no divisor exists that could be zero. *)
let split_limb (v : int) : int * int = (v land (base - 1), v lsr limb_bits)

let zeros (n : int) : int list = List.init n (fun _ -> 0)

let zero : t = zeros limbs

(* Pairs two digit lists, padding the shorter one with zero digits. *)
let rec zip2 (xs : int list) (ys : int list) : (int * int) list =
  match (xs, ys) with
  | ([], []) -> []
  | ([], y :: ys') -> (0, y) :: zip2 [] ys'
  | (x :: xs', []) -> (x, 0) :: zip2 xs' []
  | (x :: xs', y :: ys') -> (x, y) :: zip2 xs' ys'

(* Normalizes unbounded non-negative digits into digits inside [0, base),
   least significant first.  The length is kept and a carry out of the top
   digit is dropped;  every call site holds its value under the capacity
   of the digits it passes in. *)
let carry_limbs (xs : int list) : int list =
  let (out, _) =
    List.fold_left
      (fun (acc, c) x ->
        let (lo, hi) = split_limb (x + c) in
        (lo :: acc, hi))
      ([], 0) xs
  in
  List.rev out

let rec cmp_go (xs : int list) (ys : int list) (acc : int) : int =
  match (xs, ys) with
  | ([], []) -> acc
  | ([], y :: ys') -> cmp_go [] ys' (if y = 0 then acc else -1)
  | (x :: xs', []) -> cmp_go xs' [] (if x = 0 then acc else 1)
  | (x :: xs', y :: ys') ->
      cmp_go xs' ys' (match Int.compare x y with 0 -> acc | d -> d)

(* Digits run least significant first, so the last disagreement wins. *)
let cmp (a : int list) (b : int list) : int = cmp_go a b 0

let equal (a : t) (b : t) : bool = cmp a b = 0

let add_raw (a : int list) (b : int list) : int list =
  carry_limbs (List.map (fun (x, y) -> x + y) (zip2 a b))

(* Digit subtraction with a borrow.  Every call site holds a >= b. *)
let sub_raw (a : int list) (b : int list) : int list =
  let (out, _) =
    List.fold_left
      (fun (acc, borrow) (x, y) ->
        let d = x - y - borrow in
        let under = d < 0 in
        ((if under then d + base else d) :: acc, if under then 1 else 0))
      ([], 0) (zip2 a b)
  in
  List.rev out

(* Multiplies by ten and adds one digit, with no reduction.  None when the
   value leaves the 11 limbs. *)
let mul10_add (xs : int list) (d : int) : int list option =
  let (out, carry) =
    List.fold_left
      (fun (acc, c) x ->
        let (lo, hi) = split_limb ((x * 10) + c) in
        (lo :: acc, hi))
      ([], d) xs
  in
  if carry = 0 then Some (List.rev out) else None

(* Decimal digits to limbs, with no reduction.  None on an empty string,
   on any byte outside the ten digits, and on 2^264 or more.  48 is the
   code of the digit zero. *)
let parse_raw (s : string) : int list option =
  let step acc ch =
    Option.bind acc (fun v ->
        let d = Char.code ch - 48 in
        if d < 0 || d > 9 then None else mul10_add v d)
  in
  if String.length s = 0 then None else String.fold_left step (Some zero) s

let p_digits =
  "21888242871839275222246405745257275088548364400416034343698204186575808495617"

(* p comes out of that same digit parser (brief section 3.2). *)
let p : int list = Option.value (parse_raw p_digits) ~default:zero

(* The bits of a digit list, least significant first. *)
let bits_le (xs : int list) : int list =
  List.concat_map (fun x -> List.init limb_bits (fun i -> (x lsr i) land 1)) xs

let dbl_add (r : int list) (bit : int) : int list =
  let (out, _) =
    List.fold_left
      (fun (acc, c) x ->
        let (lo, hi) = split_limb ((x * 2) + c) in
        (lo :: acc, hi))
      ([], bit) r
  in
  List.rev out

(* Reduction against p as binary long division over the bits of the input,
   one fold from the top bit down.  The running remainder stays under p,
   so twice it plus one stays under 2p and inside the 11 limbs.  This is
   the reduction the 22-limb product goes through. *)
let rem_p (xs : int list) : t =
  List.fold_left
    (fun r bit ->
      let d = dbl_add r bit in
      if cmp d p >= 0 then sub_raw d p else d)
    zero
    (List.rev (bits_le xs))

let of_int (n : int) : t =
  if n < 0 then zero else rem_p (carry_limbs (n :: zeros (limbs - 1)))

let one : t = of_int 1
let of_decimal (s : string) : t option = Option.map rem_p (parse_raw s)

let add (a : t) (b : t) : t =
  let s = add_raw a b in
  if cmp s p >= 0 then sub_raw s p else s

let neg (a : t) : t = if equal a zero then zero else sub_raw p a
let sub (a : t) (b : t) : t = add a (neg b)

(* Schoolbook product into 22 digits, each under 11 * 2^48, then the
   binary reduction.  Digit i of a scales b and lands i places up. *)
let mul (a : t) (b : t) : t =
  let (acc, _) =
    List.fold_left
      (fun (acc, i) ai ->
        ( List.map (fun (x, y) -> x + y)
            (zip2 acc (zeros i @ List.map (fun bj -> ai * bj) b)),
          i + 1 ))
      (zeros (2 * limbs), 0)
      a
  in
  rem_p (carry_limbs acc)

let pow7 (x : t) : t =
  let t2 = mul x x in
  let t4 = mul t2 t2 in
  let t6 = mul t4 t2 in
  mul t6 x

(* The 256 one-byte strings come out of this literal, so the module needs
   no partial character constructor of any kind. *)
let all_bytes : string =
  "\000\001\002\003\004\005\006\007\008\009\010\011\012\013\014\015\016\017\018\019\020\021\022\023\024\025\026\027\028\029\030\031"
  ^ "\032\033\034\035\036\037\038\039\040\041\042\043\044\045\046\047\048\049\050\051\052\053\054\055\056\057\058\059\060\061\062\063"
  ^ "\064\065\066\067\068\069\070\071\072\073\074\075\076\077\078\079\080\081\082\083\084\085\086\087\088\089\090\091\092\093\094\095"
  ^ "\096\097\098\099\100\101\102\103\104\105\106\107\108\109\110\111\112\113\114\115\116\117\118\119\120\121\122\123\124\125\126\127"
  ^ "\128\129\130\131\132\133\134\135\136\137\138\139\140\141\142\143\144\145\146\147\148\149\150\151\152\153\154\155\156\157\158\159"
  ^ "\160\161\162\163\164\165\166\167\168\169\170\171\172\173\174\175\176\177\178\179\180\181\182\183\184\185\186\187\188\189\190\191"
  ^ "\192\193\194\195\196\197\198\199\200\201\202\203\204\205\206\207\208\209\210\211\212\213\214\215\216\217\218\219\220\221\222\223"
  ^ "\224\225\226\227\228\229\230\231\232\233\234\235\236\237\238\239\240\241\242\243\244\245\246\247\248\249\250\251\252\253\254\255"

let byte_table : string list =
  List.of_seq (Seq.map (fun ch -> String.make 1 ch) (String.to_seq all_bytes))

(* Total selection out of a list by position: the fold keeps the entry
   whose position matches, so no indexing and no partial accessor. *)
let pick (n : int) (xs : string list) : string =
  fst
    (List.fold_left
       (fun (out, i) x -> ((if i = n then x else out), i + 1))
       ("", 0) xs)

(* One byte as a one-byte string.  The writers share this spelling, so the
   two file kinds cannot drift apart. *)
let byte_string (n : int) : string = pick (n land 255) byte_table

let digit_string (d : int) : string =
  pick d [ "0"; "1"; "2"; "3"; "4"; "5"; "6"; "7"; "8"; "9" ]

let string_of_bytes (bs : int list) : string =
  String.concat "" (List.map byte_string bs)

(* The limb base is 2^24, so one limb is exactly three bytes and 11 limbs
   are 33.  A value stays under 2^254, so byte 32 is zero and the first 32
   bytes carry the whole element, little-endian, as both file kinds ask. *)
let to_bytes_le (a : t) : string =
  string_of_bytes
    (List.filteri
       (fun i _ -> i < width)
       (List.concat_map
          (fun x -> [ x land 255; (x lsr 8) land 255; (x lsr 16) land 255 ])
          a))

let prime_bytes_le : string = to_bytes_le p

(* Doubles a decimal digit list and adds one bit, digits least significant
   first.  The decimal carry comes out of a comparison, so the printer
   needs no divisor of its own. *)
let dec_double (ds : int list) (bit : int) : int list =
  let (out, carry) =
    List.fold_left
      (fun (acc, c) d ->
        let v = (d * 2) + c in
        if v >= 10 then ((v - 10) :: acc, 1) else (v :: acc, 0))
      ([], bit) ds
  in
  List.rev (if carry = 0 then out else carry :: out)

(* Binary to decimal, one bit at a time from the top, then the leading
   zeros are dropped and the digits are rendered. *)
let to_decimal (a : t) : string =
  let ds_le = List.fold_left dec_double [ 0 ] (List.rev (bits_le a)) in
  let kept =
    List.fold_left
      (fun acc d -> if acc = [] && d = 0 then acc else d :: acc)
      [] (List.rev ds_le)
  in
  match List.rev kept with
  | [] -> "0"
  | d :: rest -> String.concat "" (List.map digit_string (d :: rest))
