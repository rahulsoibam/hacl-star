module Hacl.Impl.Curve25519.AddAndDouble

open FStar.HyperStack
open FStar.HyperStack.All
open FStar.Mul

open Lib.IntTypes
open Lib.Buffer
open Lib.ByteBuffer

open Hacl.Impl.Curve25519.Fields

module ST = FStar.HyperStack.ST

module F26 = Hacl.Impl.Curve25519.Field26
module F51 = Hacl.Impl.Curve25519.Field51
module F64 = Hacl.Impl.Curve25519.Field64

module P = Spec.Curve25519
module S = Hacl.Spec.Curve25519.AddAndDouble

#reset-options "--z3rlimit 50 --max_fuel 2 --using_facts_from '* -FStar.Seq'"

inline_for_extraction
let point (s:field_spec) = lbuffer (limb s) (nlimb s +! nlimb s)

(* NEEDED ONLY FOR WRAPPERS *)
inline_for_extraction
let point26 = lbuffer uint64 20ul
inline_for_extraction
let point51 = lbuffer uint64 10ul
inline_for_extraction
let point64 = lbuffer uint64 8ul
(* NEEDED ONLY FOR WRAPPERS *)

let get_x #s (p:point s) = gsub p 0ul (nlimb s)
let get_z #s (p:point s) = gsub p (nlimb s) (nlimb s)

let fget_x (#s:field_spec) (h:mem) (p:point s) = feval h (gsub p 0ul (nlimb s))
let fget_z (#s:field_spec) (h:mem) (p:point s) = feval h (gsub p (nlimb s) (nlimb s))
let fget_xz (#s:field_spec) (h:mem) (p:point s) = fget_x h p, fget_z h p

val state_inv_t:#s:field_spec -> h:mem -> f:felem s -> Type0
let state_inv_t #s h f =
  match s with
  | M26 -> True
  | M51 -> F51.mul_inv_t h f
  | M64 -> True

val point_tmp_inv_t:#s:field_spec -> h:mem -> f:felem s -> Type0
let point_tmp_inv_t #s h f =
  match s with
  | M26 -> True
  | M51 -> F51.felem_fits h f (9, 10, 9, 9, 9)
  | M64 -> True

//#set-options "--z3rlimit 150"

inline_for_extraction
val point_add_and_double0:
    #s:field_spec{s == M51 \/ s == M64}
  -> q:point s
  -> nq:point s
  -> nq_p1:point s
  -> ab:lbuffer (limb s) (2ul *. nlimb s)
  -> dc:lbuffer (limb s) (2ul *. nlimb s)
  -> tmp2:felem_wide2 s
  -> Stack unit
    (requires fun h0 ->
      live h0 q /\ live h0 nq /\ live h0 nq_p1 /\ live h0 ab /\ live h0 dc /\ live h0 tmp2 /\
      disjoint q nq /\ disjoint q nq_p1 /\ disjoint q ab /\ disjoint q dc /\ disjoint q tmp2 /\
      disjoint nq q /\ disjoint nq nq_p1 /\ disjoint nq ab /\ disjoint nq dc /\ disjoint nq tmp2 /\
      disjoint nq_p1 ab /\ disjoint nq_p1 dc /\ disjoint nq_p1 tmp2 /\
      disjoint ab dc /\ disjoint ab tmp2 /\ disjoint dc tmp2 /\
      state_inv_t h0 (get_x q) /\ state_inv_t h0 (get_z q) /\
      state_inv_t h0 (get_x nq) /\ state_inv_t h0 (get_z nq) /\
      state_inv_t h0 (get_x nq_p1) /\ state_inv_t h0 (get_z nq_p1) /\
      point_tmp_inv_t h0 (gsub ab 0ul (nlimb s)) /\
      point_tmp_inv_t h0 (gsub ab (nlimb s) (nlimb s)) /\
      feval h0 (gsub ab 0ul (nlimb s)) == P.fadd (fget_x h0 nq) (fget_z h0 nq) /\
      feval h0 (gsub ab (nlimb s) (nlimb s)) == P.fsub (fget_x h0 nq) (fget_z h0 nq))
    (ensures  fun h0 _ h1 ->
      modifies (loc nq_p1 |+| loc dc |+| loc tmp2) h0 h1 /\
      state_inv_t h1 (get_x nq_p1) /\ state_inv_t h1 (get_z nq_p1) /\
      fget_xz h1 nq_p1 == S.add (fget_xz h0 q) (fget_xz h0 nq) (fget_xz h0 nq_p1))
let point_add_and_double0 #s q nq nq_p1 ab dc tmp2 =
  let x1 = sub q 0ul (nlimb s) in
  let z1 = sub q (nlimb s) (nlimb s) in
  let x2 = sub nq 0ul (nlimb s) in
  let z2 = sub nq (nlimb s) (nlimb s) in
  let x3 = sub nq_p1 0ul (nlimb s) in
  let z3 = sub nq_p1 (nlimb s) (nlimb s) in
  let a : felem s = sub ab 0ul (nlimb s) in
  let b : felem s = sub ab (nlimb s) (nlimb s) in
  let d : felem s = sub dc 0ul (nlimb s) in
  let c : felem s = sub dc (nlimb s) (nlimb s) in

  let h0 = ST.get () in
  assert (gsub q 0ul (nlimb s) == x1);
  assert (gsub q (nlimb s) (nlimb s) == z1);
  assert (gsub nq 0ul (nlimb s) == x2);
  assert (gsub nq (nlimb s) (nlimb s) == z2);
  assert (gsub nq_p1 0ul (nlimb s) == x3);
  assert (gsub nq_p1 (nlimb s) (nlimb s) == z3);
  assert (gsub ab 0ul (nlimb s) == a);
  assert (gsub ab (nlimb s) (nlimb s) == b);
  assert (gsub dc 0ul (nlimb s) == d);
  assert (gsub dc (nlimb s) (nlimb s) == c);

  assert (feval h0 a == P.fadd (feval h0 x2) (feval h0 z2));
  assert (feval h0 b == P.fsub (feval h0 x2) (feval h0 z2));
  //fadd a x2 z2; // a = x2 + z2
  //fsub b x2 z2; // b = x2 - z2
  fadd c x3 z3; // c = x3 + z3
  fsub d x3 z3; // d = x3 - z3
  let h1 = ST.get () in
  assert (feval h1 a == P.fadd (feval h0 x2) (feval h0 z2));
  assert (feval h1 b == P.fsub (feval h0 x2) (feval h0 z2));
  assert (feval h1 c == P.fadd (feval h0 x3) (feval h0 z3));
  assert (feval h1 d == P.fsub (feval h0 x3) (feval h0 z3));

  (* CAN RUN IN PARALLEL *)
  //fmul d d a;   // d = da = d * a
  //fmul c c b;   // c = cb = c * b
  fmul2 dc dc ab tmp2;   // d|c = d*a|c*b
  let h2 = ST.get () in
  assert (feval h2 d == P.fmul (feval h1 d) (feval h1 a));
  assert (feval h2 c == P.fmul (feval h1 c) (feval h1 b));
  fadd x3 d c;  // x3 = da + cb
  fsub z3 d c;  // z3 = da - cb
  let h3 = ST.get () in
  assert (feval h3 x3 == P.fadd (feval h2 d) (feval h2 c));
  assert (feval h3 z3 == P.fsub (feval h2 d) (feval h2 c));

  //moving the following line gave me a 2k speedup.
  (* CAN RUN IN PARALLEL *)
  //fsqr x3 x3;   // x3 = (da + cb) ^ 2
  //fsqr z3 z3;   // z3 = (da - cb) ^ 2
  fsqr2 nq_p1 nq_p1 tmp2;   // x3|z3 = x3*x3|z3*z3
  let h4 = ST.get () in
  assert (feval h4 x3 == P.fmul (feval h3 x3) (feval h3 x3));
  assert (feval h4 z3 == P.fmul (feval h3 z3) (feval h3 z3));
  // moving the following line gives a 2k speedup
  fmul z3 z3 x1 tmp2; // z3 = x1 * (da - cb) ^ 2
  let h5 = ST.get () in
  assert (feval h5 z3 == P.fmul (feval h4 z3) (feval h4 x1))

inline_for_extraction
val point_add_and_double1:
    #s:field_spec{s == M51 \/ s == M64}
  -> nq:point s
  -> tmp1:lbuffer (limb s) (4ul *. nlimb s)
  -> tmp2:felem_wide2 s
  -> Stack unit
    (requires fun h0 ->
      live h0 nq /\ live h0 tmp1 /\ live h0 tmp2 /\
      disjoint nq tmp1 /\ disjoint nq tmp2 /\ disjoint tmp1 tmp2 /\
      state_inv_t h0 (get_x nq) /\ state_inv_t h0 (get_z nq) /\
      point_tmp_inv_t h0 (gsub tmp1 0ul (nlimb s)) /\
      point_tmp_inv_t h0 (gsub tmp1 (nlimb s) (nlimb s)) /\
      feval h0 (gsub tmp1 0ul (nlimb s)) == P.fadd (fget_x h0 nq) (fget_z h0 nq) /\
      feval h0 (gsub tmp1 (nlimb s) (nlimb s)) == P.fsub (fget_x h0 nq) (fget_z h0 nq))
    (ensures  fun h0 _ h1 ->
      modifies (loc nq |+| loc tmp1 |+| loc tmp2) h0 h1 /\
      state_inv_t h1 (get_x nq) /\ state_inv_t h1 (get_z nq) /\
      fget_xz h1 nq == P.double (fget_xz h0 nq))
let point_add_and_double1 #s nq tmp1 tmp2 =
  let x2 = sub nq 0ul (nlimb s) in
  let z2 = sub nq (nlimb s) (nlimb s) in

  let a : felem s = sub tmp1 0ul (nlimb s) in
  let b : felem s = sub tmp1 (nlimb s) (nlimb s) in
  let d : felem s = sub tmp1 (2ul *. nlimb s) (nlimb s) in
  let c : felem s = sub tmp1 (3ul *. nlimb s) (nlimb s) in

  let ab : felem2 s = sub tmp1 0ul (2ul *. nlimb s) in
  let dc : felem2 s = sub tmp1 (2ul *. nlimb s) (2ul *. nlimb s) in
  let h0 = ST.get () in
  assert (gsub nq 0ul (nlimb s) == x2);
  assert (gsub nq (nlimb s) (nlimb s) == z2);
  assert (gsub ab 0ul (nlimb s) == a);
  assert (gsub ab (nlimb s) (nlimb s) == b);
  assert (gsub dc 0ul (nlimb s) == d);
  assert (gsub dc (nlimb s) (nlimb s) == c);

  assert (feval h0 a == P.fadd (feval h0 x2) (feval h0 z2));
  assert (feval h0 b == P.fsub (feval h0 x2) (feval h0 z2));
  //fadd a x2 z2; // a = x2 + z2
  //fsub b x2 z2; // b = x2 - z2

  (* CAN RUN IN PARALLEL *)
  //fsqr d a;     // d = aa = a^2
  //fsqr c b;     // c = bb = b^2
  fsqr2 dc ab tmp2;     // d|c = aa | bb
  copy_felem a c;                           // a = bb
  fsub c d c;   // c = e = aa - bb
  fmul1 b c (u64 121665); // b = e * 121665
  fadd b b d;   // b = (e * 121665) + aa

  (* CAN RUN IN PARALLEL *)
  //fmul x2 d a;  // x2 = aa * bb
  //fmul z2 c b;  // z2 = e * (aa + (e * 121665))
  fmul2 nq dc ab tmp2  // x2|z2 = aa * bb | e * (aa + (e * 121665))

inline_for_extraction
val point_add_and_double_:
    #s:field_spec{s == M51 \/ s == M64}
  -> q:point s
  -> nq:point s
  -> nq_p1:point s
  -> tmp1:lbuffer (limb s) (4ul *. nlimb s)
  -> tmp2:felem_wide2 s
  -> Stack unit
    (requires fun h0 ->
      live h0 q /\ live h0 nq /\ live h0 nq_p1 /\ live h0 tmp1 /\ live h0 tmp2 /\
      disjoint q nq /\ disjoint q nq_p1 /\ disjoint q tmp1 /\ disjoint q tmp2 /\
      disjoint nq q /\ disjoint nq nq_p1 /\ disjoint nq tmp1 /\ disjoint nq tmp2 /\
      disjoint nq_p1 tmp1 /\ disjoint nq_p1 tmp2 /\ disjoint tmp1 tmp2 /\
      state_inv_t h0 (get_x q) /\ state_inv_t h0 (get_z q) /\
      state_inv_t h0 (get_x nq) /\ state_inv_t h0 (get_z nq) /\
      state_inv_t h0 (get_x nq_p1) /\ state_inv_t h0 (get_z nq_p1))
    (ensures  fun h0 _ h1 ->
      modifies (loc nq |+| loc nq_p1 |+| loc tmp1 |+| loc tmp2) h0 h1 /\
      state_inv_t h1 (get_x nq) /\ state_inv_t h1 (get_z nq) /\
      state_inv_t h1 (get_x nq_p1) /\ state_inv_t h1 (get_z nq_p1) /\
     (let p2, p3 = P.add_and_double (fget_xz h0 q) (fget_xz h0 nq) (fget_xz h0 nq_p1) in
      fget_xz h1 nq == p2 /\ fget_xz h1 nq_p1 == p3))
let point_add_and_double_ #s q nq nq_p1 tmp1 tmp2 =
  let x2 = sub nq 0ul (nlimb s) in
  let z2 = sub nq (nlimb s) (nlimb s) in

  let a : felem s = sub tmp1 0ul (nlimb s) in
  let b : felem s = sub tmp1 (nlimb s) (nlimb s) in
  let ab : felem2 s = sub tmp1 0ul (2ul *. nlimb s) in
  let dc : felem2 s = sub tmp1 (2ul *. nlimb s) (2ul *. nlimb s) in

  let h0 = ST.get () in
  assert (gsub nq 0ul (nlimb s) == x2);
  assert (gsub nq (nlimb s) (nlimb s) == z2);
  fadd a x2 z2; // a = x2 + z2
  fsub b x2 z2; // b = x2 - z2

  point_add_and_double0 #s q nq nq_p1 ab dc tmp2;
  point_add_and_double1 #s nq tmp1 tmp2

(* WRAPPER to Prevent Inlining *)
[@CInline]
let point_add_and_double_26 (q:point26) (nq:point26) (nq_p1:point26) tmp1 tmp2 = admit(); point_add_and_double_ #M26 q nq nq_p1 tmp1 tmp2
[@CInline]
let point_add_and_double_51 (q:point51) (nq:point51) (nq_p1:point51) tmp1 tmp2 = point_add_and_double_ #M51 q nq nq_p1 tmp1 tmp2
[@CInline]
let point_add_and_double_64 (q:point64) (nq:point64) (nq_p1:point64) tmp1 tmp2 = point_add_and_double_ #M64 q nq nq_p1 tmp1 tmp2

inline_for_extraction
val point_add_and_double:
    #s:field_spec
  -> q:point s
  -> nq: point s
  -> nq_p1:point s
  -> tmp1:lbuffer (limb s) (4ul *. nlimb s)
  -> tmp2:felem_wide2 s
  -> Stack unit
    (requires fun h0 ->
      live h0 q /\ live h0 nq /\ live h0 nq_p1 /\ live h0 tmp1 /\ live h0 tmp2 /\
      disjoint q nq /\ disjoint q nq_p1 /\ disjoint q tmp1 /\ disjoint q tmp2 /\
      disjoint nq q /\ disjoint nq nq_p1 /\ disjoint nq tmp1 /\ disjoint nq tmp2 /\
      disjoint nq_p1 tmp1 /\ disjoint nq_p1 tmp2 /\ disjoint tmp1 tmp2 /\
      state_inv_t h0 (get_x q) /\ state_inv_t h0 (get_z q) /\
      state_inv_t h0 (get_x nq) /\ state_inv_t h0 (get_z nq) /\
      state_inv_t h0 (get_x nq_p1) /\ state_inv_t h0 (get_z nq_p1))
    (ensures  fun h0 _ h1 ->
      modifies (loc nq |+| loc nq_p1 |+| loc tmp1 |+| loc tmp2) h0 h1 /\
      state_inv_t h1 (get_x nq) /\ state_inv_t h1 (get_z nq) /\
      state_inv_t h1 (get_x nq_p1) /\ state_inv_t h1 (get_z nq_p1) /\
     (let p2, p3 = P.add_and_double (fget_xz h0 q) (fget_xz h0 nq) (fget_xz h0 nq_p1) in
      fget_xz h1 nq == p2 /\ fget_xz h1 nq_p1 == p3))
let point_add_and_double #s q nq nq_p1 tmp1 tmp2 =
  match s with
  | M26 -> point_add_and_double_26 q nq nq_p1 tmp1 tmp2
  | M51 -> point_add_and_double_51 q nq nq_p1 tmp1 tmp2
  | M64 -> point_add_and_double_64 q nq nq_p1 tmp1 tmp2
(* WRAPPER to Prevent Inlining *)


inline_for_extraction
val point_double_:
    #s:field_spec{s == M51 \/ s == M64}
  -> nq:point s
  -> tmp1:lbuffer (limb s) (4ul *. nlimb s)
  -> tmp2:felem_wide2 s
  -> Stack unit
    (requires fun h0 ->
      live h0 nq /\ live h0 tmp1 /\ live h0 tmp2 /\
      disjoint nq tmp1 /\ disjoint nq tmp2 /\ disjoint tmp1 tmp2 /\
      state_inv_t h0 (get_x nq) /\ state_inv_t h0 (get_z nq))
    (ensures  fun h0 _ h1 ->
      modifies (loc nq |+| loc tmp1 |+| loc tmp2) h0 h1 /\
      state_inv_t h1 (get_x nq) /\ state_inv_t h1 (get_z nq) /\
      fget_xz h1 nq == P.double (fget_xz h0 nq))
let point_double_ #s nq tmp1 tmp2 =
  let x2 = sub nq 0ul (nlimb s) in
  let z2 = sub nq (nlimb s) (nlimb s) in

  let a : felem s = sub tmp1 0ul (nlimb s) in
  let b : felem s = sub tmp1 (nlimb s) (nlimb s) in
  let d : felem s = sub tmp1 (2ul *. nlimb s) (nlimb s) in
  let c : felem s = sub tmp1 (3ul *. nlimb s) (nlimb s) in

  let ab : felem2 s = sub tmp1 0ul (2ul *. nlimb s) in
  let dc : felem2 s = sub tmp1 (2ul *. nlimb s) (2ul *. nlimb s) in
  let h0 = ST.get () in
  assert (gsub nq 0ul (nlimb s) == x2);
  assert (gsub nq (nlimb s) (nlimb s) == z2);
  assert (gsub ab 0ul (nlimb s) == a);
  assert (gsub ab (nlimb s) (nlimb s) == b);
  assert (gsub dc 0ul (nlimb s) == d);
  assert (gsub dc (nlimb s) (nlimb s) == c);

  fadd a x2 z2; // a = x2 + z2
  fsub b x2 z2; // b = x2 - z2

  (* CAN RUN IN PARALLEL *)
  //fsqr d a;     // d = aa = a^2
  //fsqr c b;     // c = bb = b^2
  fsqr2 dc ab tmp2;     // d|c = aa | bb
  copy_felem a c;                           // a = bb
  fsub c d c;   // c = e = aa - bb
  fmul1 b c (u64 121665); // b = e * 121665
  fadd b b d;   // b = (e * 121665) + aa

  (* CAN RUN IN PARALLEL *)
  //fmul x2 d a;  // x2 = aa * bb
  //fmul z2 c b;  // z2 = e * (aa + (e * 121665))
  fmul2 nq dc ab tmp2  // x2|z2 = aa * bb | e * (aa + (e * 121665))

(* WRAPPER to Prevent Inlining *)
[@CInline]
let point_double_26 (nq:point26) tmp1 tmp2 = admit(); point_double_ #M26 nq  tmp1 tmp2
[@CInline]
let point_double_51 (nq:point51) tmp1 tmp2 = point_double_ #M51 nq tmp1 tmp2
[@CInline]
let point_double_64 (nq:point64) tmp1 tmp2 = point_double_ #M64 nq tmp1 tmp2

inline_for_extraction
val point_double:
    #s:field_spec
  -> nq: point s
  -> tmp1:lbuffer (limb s) (4ul *. nlimb s)
  -> tmp2:felem_wide2 s
  -> Stack unit
    (requires fun h0 ->
      live h0 nq /\ live h0 tmp1 /\ live h0 tmp2 /\
      disjoint nq tmp1 /\ disjoint nq tmp2 /\ disjoint tmp1 tmp2 /\
      state_inv_t h0 (get_x nq) /\ state_inv_t h0 (get_z nq))
    (ensures  fun h0 _ h1 ->
      modifies (loc nq |+| loc tmp1 |+| loc tmp2) h0 h1 /\
      state_inv_t h1 (get_x nq) /\ state_inv_t h1 (get_z nq) /\
      fget_xz h1 nq == P.double (fget_xz h0 nq))
let point_double #s nq tmp1 tmp2 =
  match s with
  | M26 -> point_double_26 nq tmp1 tmp2
  | M51 -> point_double_51 nq tmp1 tmp2
  | M64 -> point_double_64 nq tmp1 tmp2
(* WRAPPER to Prevent Inlining *)