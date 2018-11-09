module Low.RVector

open FStar.All
open FStar.Integers
open FStar.Classical
open LowStar.Modifies
open Low.Regional
open Low.Vector

module HH = FStar.Monotonic.HyperHeap
module HS = FStar.HyperStack
module HST = FStar.HyperStack.ST
module MHS = FStar.Monotonic.HyperStack
module S = FStar.Seq
module B = LowStar.Buffer
module V = Low.Vector

module U64 = FStar.UInt64

/// Utilities

// `HST.new_region` does not guarantee `modifies loc_none h0 h1`, which is
// a bit annoying. It can be proven by `B.modifies_none_modifies` and here
// `new_region_` is exactly doing that.
val new_region_:
  r0:HH.rid ->
  HST.ST HH.rid
    (fun _ -> HST.is_eternal_region r0)
    (fun h0 r1 h1 ->
      MHS.fresh_region r1 h0 h1 /\
      HH.extends r1 r0 /\
      MHS.get_hmap h1 == Map.upd (MHS.get_hmap h0) r1 Monotonic.Heap.emp /\
      HH.color r1 = HH.color r0 /\
      HyperStack.ST.is_eternal_region r1 /\
      modifies loc_none h0 h1)
let new_region_ r0 =
  let hh0 = HST.get () in
  let r1 = HST.new_region r0 in
  let hh1 = HST.get () in
  B.modifies_none_modifies hh0 hh1;
  r1

// A `regional` type `a` is also `copyable` when there exists a copy operator
// that guarantees the same representation between `src` and `dst`.
// For instance, the `copy` operation for `B.buffer a` is `B.blit`.
noeq type copyable a (rg: regional a) =
| Cpy:
    copy: (src:a -> dst:a ->
      HST.ST unit
    	(requires (fun h0 ->
    	  Rgl?.r_inv rg h0 src /\ Rgl?.r_inv rg h0 dst /\
    	  HH.disjoint (Rgl?.region_of rg src)
		      (Rgl?.region_of rg dst)))
    	(ensures (fun h0 _ h1 ->
    	  modifies (loc_all_regions_from
		     false (Rgl?.region_of rg dst)) h0 h1 /\
    	  Rgl?.r_inv rg h1 dst /\
    	  Rgl?.r_repr rg h1 dst == Rgl?.r_repr rg h0 src))) ->
    copyable a rg

type rvector #a (rg:regional a) = V.vector a

val loc_rvector:
  #a:Type0 -> #rg:regional a -> rv:rvector rg -> GTot loc
let loc_rvector #a #rg rv =
  loc_all_regions_from false (V.frameOf rv)

/// The invariant of `rvector`
// Here we will define the invariant for `rvector #a` that contains
// the invariant for each element and some more about the vector itself.

val rs_elems_inv:
  #a:Type0 -> rg:regional a ->
  h:HS.mem -> rs:S.seq a ->
  i:nat -> j:nat{i <= j && j <= S.length rs} ->
  GTot Type0
let rs_elems_inv #a rg h rs i j =
  V.forall_seq rs i j (Rgl?.r_inv rg h)

val rv_elems_inv:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg ->
  i:uint64_t -> j:uint64_t{i <= j && j <= V.size_of rv} ->
  GTot Type0
let rv_elems_inv #a #rg h rv i j =
  rs_elems_inv rg h (V.as_seq h rv) (U64.v i) (U64.v j)

val elems_inv:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg ->
  GTot Type0
let elems_inv #a #rg h rv =
  rv_elems_inv h rv 0UL (V.size_of rv)

val rs_elems_reg:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a -> prid:HH.rid ->
  i:nat -> j:nat{i <= j && j <= S.length rs} ->
  GTot Type0
let rs_elems_reg #a rg rs prid i j =
  V.forall_seq rs i j
    (fun v -> HH.extends (Rgl?.region_of rg v) prid) /\
  V.forall2_seq rs i j
    (fun v1 v2 -> HH.disjoint (Rgl?.region_of rg v1)
			      (Rgl?.region_of rg v2))

val rv_elems_reg:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg ->
  i:uint64_t -> j:uint64_t{i <= j && j <= V.size_of rv} ->
  GTot Type0
let rv_elems_reg #a #rg h rv i j =
  rs_elems_reg rg (V.as_seq h rv) (V.frameOf rv) (U64.v i) (U64.v j)

val elems_reg:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg ->
  GTot Type0
let elems_reg #a #rg h rv =
  rv_elems_reg h rv 0UL (V.size_of rv)

val rv_itself_inv:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg -> GTot Type0
let rv_itself_inv #a #rg h rv =
  V.live h rv /\ V.freeable rv /\
  HST.is_eternal_region (V.frameOf rv)

// This is the invariant of `rvector`.
val rv_inv:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg -> GTot Type0
let rv_inv #a #rg h rv =
  elems_inv h rv /\
  elems_reg h rv /\
  rv_itself_inv h rv

val rs_elems_inv_live_region:
  #a:Type0 -> rg:regional a ->
  h:HS.mem -> rs:S.seq a ->
  i:nat -> j:nat{i <= j && j <= S.length rs} ->
  Lemma (requires (rs_elems_inv rg h rs i j))
	(ensures (V.forall_seq rs i j
		   (fun r -> MHS.live_region h (Rgl?.region_of rg r))))
let rec rs_elems_inv_live_region #a rg h rs i j =
  if i = j then ()
  else (Rgl?.r_inv_reg rg h (S.index rs (j - 1));
       rs_elems_inv_live_region rg h rs i (j - 1))

val rv_elems_inv_live_region:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg ->
  i:uint64_t -> j:uint64_t{i <= j && j <= V.size_of rv} ->
  Lemma (requires (rv_elems_inv h rv i j))
	(ensures (V.forall_ h rv i j
		   (fun r -> MHS.live_region h (Rgl?.region_of rg r))))
let rv_elems_inv_live_region #a #rg h rv i j =
  rs_elems_inv_live_region rg h (V.as_seq h rv) (U64.v i) (U64.v j)

/// Utilities for fine-grained region control

val rs_loc_elem:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a -> i:nat{i < S.length rs} ->
  GTot loc
let rs_loc_elem #a rg rs i =
  loc_all_regions_from false (Rgl?.region_of rg (S.index rs i))

val rs_loc_elems:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a -> i:nat -> j:nat{i <= j && j <= S.length rs} ->
  GTot loc (decreases j)
let rec rs_loc_elems #a rg rs i j =
  if i = j then loc_none
  else loc_union (rs_loc_elems rg rs i (j - 1))
		 (rs_loc_elem rg rs (j - 1))

val rv_loc_elems:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg ->
  i:uint64_t -> j:uint64_t{i <= j && j <= V.size_of rv} ->
  GTot loc
let rv_loc_elems #a #rg h rv i j =
  rs_loc_elems rg (V.as_seq h rv) (U64.v i) (U64.v j)

// Properties about inclusion of locations

val rs_loc_elems_rec_inverse:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a ->
  i:nat -> j:nat{i < j && j <= S.length rs} ->
  Lemma (requires true)
	(ensures (rs_loc_elems rg rs i j ==
		 loc_union (rs_loc_elem rg rs i)
			   (rs_loc_elems rg rs (i + 1) j)))
	(decreases j)
let rec rs_loc_elems_rec_inverse #a rg rs i j =
  if i + 1 = j then ()
  else (assert (rs_loc_elems rg rs i j ==
	       loc_union (rs_loc_elems rg rs i (j - 1))
			 (rs_loc_elem rg rs (j - 1)));
       assert (rs_loc_elems rg rs (i + 1) j ==
	      loc_union (rs_loc_elems rg rs (i + 1) (j - 1))
			(rs_loc_elem rg rs (j - 1)));
       rs_loc_elems_rec_inverse rg rs i (j - 1);
       assert (rs_loc_elems rg rs i j ==
	      loc_union (loc_union
			  (rs_loc_elem rg rs i)
			  (rs_loc_elems rg rs (i + 1) (j - 1)))
			(rs_loc_elem rg rs (j - 1)));
       loc_union_assoc (rs_loc_elem rg rs i)
		       (rs_loc_elems rg rs (i + 1) (j - 1))
		       (rs_loc_elem rg rs (j - 1)))

val rs_loc_elems_includes:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a ->
  i:nat -> j:nat{i <= j && j <= S.length rs} ->
  k:nat{i <= k && k < j} ->
  Lemma (loc_includes (rs_loc_elems rg rs i j)
		      (rs_loc_elem rg rs k))
let rec rs_loc_elems_includes #a rg rs i j k =
  if k = j - 1 then ()
  else rs_loc_elems_includes #a rg rs i (j - 1) k

val loc_all_exts_from:
  preserve_liveness: bool -> r: HH.rid -> GTot loc
let loc_all_exts_from preserve_liveness r =
  B.loc_regions
    preserve_liveness
    (Set.intersect
      (HS.mod_set (Set.singleton r))
      (Set.complement (Set.singleton r)))

val rs_loc_elem_included:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a -> prid:HH.rid ->
  i:nat{i < S.length rs} ->
  Lemma (requires (HH.extends (Rgl?.region_of rg (S.index rs i)) prid))
	(ensures (loc_includes (loc_all_exts_from false prid)
  			       (rs_loc_elem rg rs i)))
let rs_loc_elem_included #a rg rs prid i = ()

val rs_loc_elems_included:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a -> prid:HH.rid ->
  i:nat -> j:nat{i <= j && j <= S.length rs} ->
  Lemma (requires (rs_elems_reg rg rs prid i j))
	(ensures (loc_includes (loc_all_exts_from false prid)
  			       (rs_loc_elems rg rs i j)))
	(decreases j)
let rec rs_loc_elems_included #a rg rs prid i j =
  if i = j then ()
  else (rs_loc_elem_included rg rs prid (j - 1);
       rs_loc_elems_included rg rs prid i (j - 1))

val rv_loc_elems_included:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg ->
  i:uint64_t -> j:uint64_t{i <= j && j <= V.size_of rv} ->
  Lemma (requires (rv_elems_reg h rv i j))
	(ensures (loc_includes (loc_all_exts_from false (V.frameOf rv))
  			       (rv_loc_elems h rv i j)))
let rv_loc_elems_included #a #rg h rv i j =
  rs_loc_elems_included rg (V.as_seq h rv) (V.frameOf rv) (U64.v i) (U64.v j)

// Properties about disjointness of locations

val rs_loc_elem_disj:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a -> prid:HH.rid ->
  i:nat -> j:nat{i <= j && j <= S.length rs} ->
  k:nat{i <= k && k < j} ->
  l:nat{i <= l && l < j && k <> l} ->
  Lemma (requires (rs_elems_reg rg rs prid i j))
	(ensures (loc_disjoint (rs_loc_elem rg rs k)
			       (rs_loc_elem rg rs l)))
let rs_loc_elem_disj #a rg rs prid i j k l = ()

val rs_loc_elem_disj_forall:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a -> prid:HH.rid ->
  i:nat -> j:nat{i <= j && j <= S.length rs} ->
  Lemma (requires (rs_elems_reg rg rs prid i j))
	(ensures (
	  forall (k:nat{i <= k && k < j}).
	  forall (l:nat{i <= l && l < j && k <> l}).
	    loc_disjoint (rs_loc_elem rg rs k)
			 (rs_loc_elem rg rs l)))
let rs_loc_elem_disj_forall #a rg rs prid i j = ()

val rs_loc_elems_elem_disj:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a -> prid:HH.rid ->
  i:nat -> j:nat{i <= j && j <= S.length rs} ->
  k1:nat{i <= k1} ->
  k2:nat{k1 <= k2 && k2 <= j} ->
  l:nat{i <= l && l < j && (l < k1 || k2 <= l)} ->
  Lemma (requires (rs_elems_reg rg rs prid i j))
	(ensures (loc_disjoint (rs_loc_elems rg rs k1 k2)
			       (rs_loc_elem rg rs l)))
	(decreases k2)
let rec rs_loc_elems_elem_disj #a rg rs prid i j k1 k2 l =
  if k1 = k2 then ()
  else (rs_loc_elem_disj rg rs prid i j (k2 - 1) l;
       rs_loc_elems_elem_disj rg rs prid i j k1 (k2 - 1) l)

val rs_loc_elems_disj:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a -> prid:HH.rid ->
  i:nat -> j:nat{i <= j && j <= S.length rs} ->
  k1:nat{i <= k1} ->
  k2:nat{k1 <= k2 && k2 <= j} ->
  l1:nat{i <= l1} ->
  l2:nat{l1 <= l2 && l2 <= j} ->
  Lemma (requires (rs_elems_reg rg rs prid i j /\ (k2 <= l1 || l2 <= k1)))
	(ensures (loc_disjoint (rs_loc_elems rg rs k1 k2)
			       (rs_loc_elems rg rs l1 l2)))
	(decreases k2)
let rec rs_loc_elems_disj #a rg rs prid i j k1 k2 l1 l2 =
  if k1 = k2 then ()
  else (rs_loc_elems_elem_disj rg rs prid i j l1 l2 (k2 - 1);
       rs_loc_elems_disj rg rs prid i j k1 (k2 - 1) l1 l2)

val rv_loc_elems_disj:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg ->
  i:uint64_t -> j:uint64_t{i <= j && j <= V.size_of rv} ->
  k1:uint64_t{i <= k1} ->
  k2:uint64_t{k1 <= k2 && k2 <= j} ->
  l1:uint64_t{i <= l1} ->
  l2:uint64_t{l1 <= l2 && l2 <= j} ->
  Lemma (requires (rv_elems_reg h rv i j /\ (k2 <= l1 || l2 <= k1)))
	(ensures (loc_disjoint (rv_loc_elems h rv k1 k2)
			       (rv_loc_elems h rv l1 l2)))
let rv_loc_elems_disj #a #rg h rv i j k1 k2 l1 l2 =
  rs_loc_elems_disj rg (V.as_seq h rv) (V.frameOf rv)
    (U64.v i) (U64.v j) (U64.v k1) (U64.v k2) (U64.v l1) (U64.v l2)

val rs_loc_elems_parent_disj:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a -> prid:HH.rid ->
  i:nat -> j:nat{i <= j && j <= S.length rs} ->
  Lemma (requires (rs_elems_reg rg rs prid i j))
	(ensures (loc_disjoint (rs_loc_elems rg rs i j)
			       (loc_region_only false prid)))
	(decreases j)
let rec rs_loc_elems_parent_disj #a rg rs prid i j =
  if i = j then ()
  else rs_loc_elems_parent_disj rg rs prid i (j - 1)

val rv_loc_elems_parent_disj:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg ->
  i:uint64_t -> j:uint64_t{i <= j && j <= V.size_of rv} ->
  Lemma (requires (rv_elems_reg h rv i j))
	(ensures (loc_disjoint (rv_loc_elems h rv i j)
			       (loc_region_only false (V.frameOf rv))))
let rv_loc_elems_parent_disj #a #rg h rv i j =
  rs_loc_elems_parent_disj rg (V.as_seq h rv) (V.frameOf rv) (U64.v i) (U64.v j)

val rs_loc_elems_each_disj:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a -> drid:HH.rid ->
  i:nat -> j:nat{i <= j && j <= S.length rs} ->
  Lemma (requires (V.forall_seq rs i j
		    (fun r -> HH.disjoint (Rgl?.region_of rg r) drid)))
	(ensures (loc_disjoint (rs_loc_elems rg rs i j)
			       (loc_all_regions_from false drid)))
	(decreases j)
let rec rs_loc_elems_each_disj #a rg rs drid i j =
  if i = j then ()
  else rs_loc_elems_each_disj rg rs drid i (j - 1)

val rv_loc_elems_each_disj:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg ->
  i:uint64_t -> j:uint64_t{i <= j && j <= V.size_of rv} ->
  drid:HH.rid ->
  Lemma (requires (V.forall_ h rv i j
		    (fun r -> HH.disjoint (Rgl?.region_of rg r) drid)))
	(ensures (loc_disjoint (rv_loc_elems h rv i j)
			       (loc_all_regions_from false drid)))
let rv_loc_elems_each_disj #a #rg h rv i j drid =
  rs_loc_elems_each_disj rg (V.as_seq h rv) drid (U64.v i) (U64.v j)

// Preservation based on disjointness

val rv_loc_elems_preserved:
  #a:Type0 -> #rg:regional a -> rv:rvector rg ->
  i:uint64_t -> j:uint64_t{i <= j && j <= V.size_of rv} ->
  p:loc -> h0:HS.mem -> h1:HS.mem ->
  Lemma (requires (V.live h0 rv /\
		  loc_disjoint p (V.loc_vector_within rv i j) /\
		  modifies p h0 h1))
	(ensures (rv_loc_elems h0 rv i j ==
		 rv_loc_elems h1 rv i j))
	(decreases (U64.v j))
let rec rv_loc_elems_preserved #a #rg rv i j p h0 h1 =
  if i = j then ()
  else (V.loc_vector_within_includes rv i j (j - 1UL) j;
       V.get_preserved rv (j - 1UL) p h0 h1;
       assert (V.get h0 rv (j - 1UL) == V.get h1 rv (j - 1UL));
       V.loc_vector_within_includes rv i j i (j - 1UL);
       rv_loc_elems_preserved rv i (j - 1UL) p h0 h1)

val rs_elems_inv_preserved:
  #a:Type0 -> rg:regional a -> rs:S.seq a ->
  i:nat -> j:nat{i <= j && j <= S.length rs} ->
  p:loc -> h0:HS.mem -> h1:HS.mem ->
  Lemma (requires (rs_elems_inv rg h0 rs i j /\
		  loc_disjoint p (rs_loc_elems rg rs i j) /\
		  modifies p h0 h1))
	(ensures (rs_elems_inv rg h1 rs i j))
	(decreases j)
let rec rs_elems_inv_preserved #a rg rs i j p h0 h1 =
  if i = j then ()
  else (rs_elems_inv_preserved rg rs i (j - 1) p h0 h1;
       Rgl?.r_sep rg (S.index rs (j - 1)) p h0 h1)

val rv_elems_inv_preserved:
  #a:Type0 -> #rg:regional a -> rv:rvector rg ->
  i:uint64_t -> j:uint64_t{i <= j && j <= V.size_of rv} ->
  p:loc -> h0:HS.mem -> h1:HS.mem ->
  Lemma (requires (V.live h0 rv /\
		  rv_elems_inv h0 rv i j /\
		  loc_disjoint p (V.loc_vector rv) /\
		  loc_disjoint p (rv_loc_elems h0 rv i j) /\
		  modifies p h0 h1))
	(ensures (rv_elems_inv h1 rv i j))
let rv_elems_inv_preserved #a #rg rv i j p h0 h1 =
  rs_elems_inv_preserved rg (V.as_seq h0 rv) (U64.v i) (U64.v j) p h0 h1

val rv_inv_preserved_:
  #a:Type0 -> #rg:regional a -> rv:rvector rg ->
  p:loc -> h0:HS.mem -> h1:HS.mem ->
  Lemma (requires (rv_inv h0 rv /\
		  loc_disjoint p (loc_vector rv) /\
		  loc_disjoint p (rv_loc_elems h0 rv 0UL (V.size_of rv)) /\
		  modifies p h0 h1))
	(ensures (rv_inv h1 rv))
let rv_inv_preserved_ #a #rg rv p h0 h1 =
  assume (V.live h1 rv);
  rv_elems_inv_preserved #a #rg rv 0UL (V.size_of rv) p h0 h1

// The first core lemma of `rvector`
val rv_inv_preserved:
  #a:Type0 -> #rg:regional a -> rv:rvector rg ->
  p:loc -> h0:HS.mem -> h1:HS.mem ->
  Lemma (requires (rv_inv h0 rv /\
		  loc_disjoint p (loc_rvector rv) /\
		  modifies p h0 h1))
	(ensures (rv_inv h1 rv))
	[SMTPat (rv_inv h0 rv);
	SMTPat (loc_disjoint p (loc_rvector rv));
	SMTPat (modifies p h0 h1)]
let rv_inv_preserved #a #rg rv p h0 h1 =
  assert (loc_includes (loc_rvector rv) (V.loc_vector rv));
  rv_loc_elems_included h0 rv 0UL (V.size_of rv);
  assert (loc_includes (loc_rvector rv) (rv_loc_elems h0 rv 0UL (V.size_of rv)));
  rv_inv_preserved_ rv p h0 h1

val rv_inv_preserved_int:
  #a:Type0 -> #rg:regional a -> rv:rvector rg ->
  i:uint64_t{i < V.size_of rv} ->
  h0:HS.mem -> h1:HS.mem ->
  Lemma (requires (rv_inv h0 rv /\
		  modifies (loc_all_regions_from false
			     (Rgl?.region_of rg (V.get h0 rv i))) h0 h1 /\
		  Rgl?.r_inv rg h1 (V.get h1 rv i)))
	(ensures (rv_inv h1 rv))
let rv_inv_preserved_int #a #rg rv i h0 h1 =
  rs_loc_elems_elem_disj
    rg (V.as_seq h0 rv) (V.frameOf rv)
    0 (U64.v (V.size_of rv)) 0 (U64.v i) (U64.v i);
  rs_elems_inv_preserved
    rg (V.as_seq h0 rv) 0 (U64.v i)
    (loc_all_regions_from false
      (Rgl?.region_of rg (V.get h1 rv i)))
    h0 h1;
  rs_loc_elems_elem_disj
    rg (V.as_seq h0 rv) (V.frameOf rv)
    0 (U64.v (V.size_of rv))
    (U64.v i + 1) (U64.v (V.size_of rv)) (U64.v i);
  rs_elems_inv_preserved
    rg (V.as_seq h0 rv) (U64.v i + 1) (U64.v (V.size_of rv))
    (loc_all_regions_from false
      (Rgl?.region_of rg (V.get h1 rv i)))
    h0 h1

/// Representation

val as_seq_seq:
  #a:Type0 -> rg:regional a ->
  h:HS.mem -> rs:S.seq a ->
  i:nat ->
  j:nat{i <= j /\ j <= S.length rs /\
    rs_elems_inv rg h rs i j} ->
  GTot (s:S.seq (Rgl?.repr rg){S.length s = j - i})
       (decreases j)
let rec as_seq_seq #a rg h rs i j =
  if i = j then S.empty
  else S.snoc (as_seq_seq rg h rs i (j - 1))
	      (Rgl?.r_repr rg h (S.index rs (j - 1)))

val as_seq_sub:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg ->
  i:uint64_t ->
  j:uint64_t{
    i <= j /\
    j <= V.size_of rv /\
    rv_elems_inv h rv i j} ->
  GTot (s:S.seq (Rgl?.repr rg){S.length s = U64.v j - U64.v i})
       (decreases (U64.v j))
let rec as_seq_sub #a #rg h rv i j =
  as_seq_seq rg h (V.as_seq h rv) (U64.v i) (U64.v j)

val as_seq:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg{rv_inv h rv} ->
  GTot (s:S.seq (Rgl?.repr rg){S.length s = U64.v (V.size_of rv)})
let rec as_seq #a #rg h rv =
  as_seq_sub h rv 0UL (V.size_of rv)

val as_seq_sub_as_seq:
  #a:Type0 -> #rg:regional a ->
  h:HS.mem -> rv:rvector rg{rv_inv h rv} ->
  Lemma (S.equal (as_seq_sub h rv 0UL (V.size_of rv))
		 (as_seq h rv))
	[SMTPat (as_seq_sub h rv 0UL (V.size_of rv))]
let as_seq_sub_as_seq #a #rg h rv = ()

val as_seq_seq_index:
  #a:Type0 -> rg:regional a ->
  h:HS.mem -> rs:S.seq a ->
  i:nat ->
  j:nat{i <= j /\ j <= S.length rs /\ rs_elems_inv rg h rs i j} ->
  k:nat{k < j - i} ->
  Lemma (requires true)
	(ensures (S.index (as_seq_seq rg h rs i j) k ==
		 Rgl?.r_repr rg h (S.index rs (i + k))))
	(decreases j)
	[SMTPat (S.index (as_seq_seq rg h rs i j) k)]
let rec as_seq_seq_index #a rg h rs i j k =
  if i = j then ()
  else if k = j - i - 1 then ()
  else as_seq_seq_index rg h rs i (j - 1) k

val as_seq_seq_eq:
  #a:Type0 -> rg:regional a ->
  h:HS.mem -> rs1:S.seq a -> rs2:S.seq a ->
  i:nat ->
  j:nat{i <= j /\ j <= S.length rs1 /\ rs_elems_inv rg h rs1 i j} ->
  k:nat ->
  l:nat{k <= l /\ l <= S.length rs2 /\ rs_elems_inv rg h rs2 k l} ->
  Lemma (requires (S.equal (S.slice rs1 i j) (S.slice rs2 k l)))
	(ensures (S.equal (as_seq_seq rg h rs1 i j)
			  (as_seq_seq rg h rs2 k l)))
let as_seq_seq_eq #a rg h rs1 rs2 i j k l =
  assert (forall (a:nat{a < j - i}).
	   S.index (as_seq_seq rg h rs1 i j) a ==
	   Rgl?.r_repr rg h (S.index rs1 (i + a)));
  assert (forall (a:nat{a < l - k}).
	   S.index (as_seq_seq rg h rs2 k l) a ==
	   Rgl?.r_repr rg h (S.index rs2 (k + a)));
  assert (S.length (S.slice rs1 i j) = j - i);
  assert (S.length (S.slice rs2 k l) = l - k);
  assert (forall (a:nat{a < j - i}).
	   S.index (S.slice rs1 i j) a ==
	   S.index (S.slice rs2 k l) a);
  assert (forall (a:nat{a < j - i}).
	   S.index rs1 (i + a) == S.index rs2 (k + a))

val as_seq_seq_slice:
  #a:Type0 -> rg:regional a ->
  h:HS.mem -> rs:S.seq a ->
  i:nat -> j:nat{i <= j /\ j <= S.length rs /\ rs_elems_inv rg h rs i j} ->
  k:nat -> l:nat{k <= l && l <= j - i} ->
  Lemma (S.equal (S.slice (as_seq_seq rg h rs i j) k l)
		 (as_seq_seq rg h (S.slice rs (i + k) (i + l)) 0 (l - k)))
#reset-options "--z3rlimit 10"
let rec as_seq_seq_slice #a rg h rs i j k l =
  if k = l then ()
  else (as_seq_seq_slice rg h rs i j k (l - 1);
       as_seq_seq_index rg h rs i j (l - 1);
       as_seq_seq_eq rg h
	 (S.slice rs (i + k) (i + l - 1))
	 (S.slice rs (i + k) (i + l))
	 0 (l - k - 1) 0 (l - k - 1))

val as_seq_seq_upd:
  #a:Type0 -> rg:regional a ->
  h:HS.mem -> rs:S.seq a ->
  i:nat ->
  j:nat{
    i <= j /\
    j <= S.length rs /\
    rs_elems_inv rg h rs i j} ->
  k:nat{i <= k && k < j} -> v:a{Rgl?.r_inv rg h v} ->
  Lemma (S.equal (as_seq_seq rg h (S.upd rs k v) i j)
		 (S.upd (as_seq_seq rg h rs i j) (k - i)
			(Rgl?.r_repr rg h v)))
let rec as_seq_seq_upd #a rg h rs i j k v =
  if i = j then ()
  else if k = j - 1 then ()
  else as_seq_seq_upd rg h rs i (j - 1) k v

// Preservation based on disjointness

val as_seq_seq_preserved:
  #a:Type0 -> rg:regional a ->
  rs:S.seq a -> i:nat -> j:nat{i <= j && j <= S.length rs} ->
  p:loc -> h0:HS.mem -> h1:HS.mem ->
  Lemma (requires (rs_elems_inv rg h0 rs i j /\
		  loc_disjoint p (rs_loc_elems rg rs i j) /\
		  modifies p h0 h1))
  	(ensures (rs_elems_inv_preserved rg rs i j p h0 h1;
		 S.equal (as_seq_seq rg h0 rs i j)
			 (as_seq_seq rg h1 rs i j)))
let rec as_seq_seq_preserved #a rg rs i j p h0 h1 =
  if i = j then ()
  else (rs_elems_inv_preserved rg rs i (j - 1) p h0 h1;
       as_seq_seq_preserved rg rs i (j - 1) p h0 h1;
       Rgl?.r_sep rg (S.index rs (j - 1)) p h0 h1)

val as_seq_sub_preserved:
  #a:Type0 -> #rg:regional a ->
  rv:rvector rg ->
  i:uint64_t -> j:uint64_t{i <= j && j <= V.size_of rv} ->
  p:loc -> h0:HS.mem -> h1:HS.mem ->
  Lemma (requires (V.live h0 rv /\
		  rv_elems_inv h0 rv i j /\
		  loc_disjoint p (rv_loc_elems h0 rv i j) /\
		  loc_disjoint p (V.loc_vector rv) /\
		  modifies p h0 h1))
  	(ensures (rv_elems_inv_preserved rv i j p h0 h1;
		 S.equal (as_seq_sub h0 rv i j)
			 (as_seq_sub h1 rv i j)))
let as_seq_sub_preserved #a #rg rv i j p h0 h1 =
  as_seq_seq_preserved rg (V.as_seq h0 rv) (U64.v i) (U64.v j) p h0 h1

val as_seq_preserved_:
  #a:Type0 -> #rg:regional a ->
  rv:rvector rg ->
  p:loc -> h0:HS.mem -> h1:HS.mem ->
  Lemma (requires (rv_inv h0 rv /\
		  loc_disjoint p (loc_vector rv) /\
		  loc_disjoint p (rv_loc_elems h0 rv 0UL (V.size_of rv)) /\
		  modifies p h0 h1))
  	(ensures (rv_inv_preserved_ rv p h0 h1;
		 S.equal (as_seq h0 rv) (as_seq h1 rv)))
let as_seq_preserved_ #a #rg rv p h0 h1 =
  as_seq_sub_preserved rv 0UL (V.size_of rv) p h0 h1

// The second core lemma of `rvector`
val as_seq_preserved:
  #a:Type0 -> #rg:regional a ->
  rv:rvector rg ->
  p:loc -> h0:HS.mem -> h1:HS.mem ->
  Lemma (requires (rv_inv h0 rv /\
		  loc_disjoint p (loc_rvector rv) /\
		  modifies p h0 h1))
  	(ensures (rv_inv_preserved rv p h0 h1;
		 S.equal (as_seq h0 rv) (as_seq h1 rv)))
	[SMTPat (rv_inv h0 rv);
	SMTPat (loc_disjoint p (loc_rvector rv));
	SMTPat (modifies p h0 h1)]
let as_seq_preserved #a #rg rv p h0 h1 =
  assert (loc_includes (loc_rvector rv) (V.loc_vector rv));
  rv_loc_elems_included h0 rv 0UL (V.size_of rv);
  assert (loc_includes (loc_rvector rv) (rv_loc_elems h0 rv 0UL (V.size_of rv)));
  as_seq_preserved_ rv p h0 h1

/// Construction

val create_empty:
  #a:Type0 -> rg:regional a ->
  HST.ST (rvector rg)
    (requires (fun h0 -> true))
    (ensures (fun h0 bv h1 -> h0 == h1 /\ V.size_of bv = 0UL))
let create_empty #a rg =
  V.create_empty a

val create_:
  #a:Type0 -> #rg:regional a -> rv:rvector rg ->
  cidx:uint64_t{cidx <= V.size_of rv} ->
  HST.ST unit
    (requires (fun h0 -> rv_itself_inv h0 rv))
    (ensures (fun h0 _ h1 ->
      modifies (V.loc_vector_within rv 0UL cidx) h0 h1 /\
      rv_itself_inv h1 rv /\
      rv_elems_inv h1 rv 0UL cidx /\
      rv_elems_reg h1 rv 0UL cidx /\
      S.equal (as_seq_sub h1 rv 0UL cidx)
      	      (S.create (U64.v cidx) (Ghost.reveal (Rgl?.irepr rg))) /\
      // the loop invariant for this function
      V.forall_ h1 rv 0UL cidx
	(fun r -> MHS.fresh_region (Rgl?.region_of rg r) h0 h1 /\
		  Rgl?.r_init_p rg r) /\
      Set.subset (Map.domain (MHS.get_hmap h0))
		 (Map.domain (MHS.get_hmap h1))))
    (decreases (U64.v cidx))
#reset-options "--z3rlimit 20"
let rec create_ #a #rg rv cidx =
  let hh0 = HST.get () in
  if cidx = 0UL then ()
  else (let nrid = new_region_ (V.frameOf rv) in
       let v = Rgl?.r_init rg nrid in

       let hh1 = HST.get () in
       V.assign rv (cidx - 1UL) v;

       let hh2 = HST.get () in
       V.loc_vector_within_included rv (cidx - 1UL) cidx;
       Rgl?.r_sep
	 rg (V.get hh2 rv (cidx - 1UL))
	 (V.loc_vector_within rv (cidx - 1UL) cidx)
	 hh1 hh2;
       create_ rv (cidx - 1UL);

       let hh3 = HST.get () in
       V.loc_vector_within_included rv 0UL (cidx - 1UL);
       Rgl?.r_sep
	 rg (V.get hh3 rv (cidx - 1UL))
	 (V.loc_vector_within rv 0UL (cidx - 1UL))
	 hh2 hh3;
       V.forall2_extend hh3 rv 0UL (cidx - 1UL)
       	 (fun r1 r2 -> HH.disjoint (Rgl?.region_of rg r1)
       				   (Rgl?.region_of rg r2));
       V.loc_vector_within_union_rev rv 0UL cidx)

val create_rid:
  #a:Type0 -> rg:regional a ->
  len:uint64_t{len > 0UL} -> rid:erid ->
  HST.ST (rvector rg)
    (requires (fun h0 -> true))
    (ensures (fun h0 rv h1 ->
      modifies (V.loc_vector rv) h0 h1 /\
      rv_inv h1 rv /\
      V.frameOf rv = rid /\
      V.size_of rv = len /\
      V.forall_all h1 rv (fun r -> Rgl?.r_init_p rg r) /\
      S.equal (as_seq h1 rv)
	      (S.create (U64.v len) (Ghost.reveal (Rgl?.irepr rg)))))
let create_rid #a rg len rid =
  let vec = V.create_rid len (Rgl?.dummy rg) rid in
  create_ #a #rg vec len;
  V.loc_vector_within_included vec 0UL len;
  vec

val create_reserve:
  #a:Type0 -> rg:regional a ->
  len:uint64_t{len > 0UL} -> rid:erid ->
  HST.ST (rvector rg)
    (requires (fun h0 -> true))
    (ensures (fun h0 rv h1 ->
      modifies (V.loc_vector rv) h0 h1 /\
      rv_inv h1 rv /\
      V.frameOf rv = rid /\
      V.size_of rv = 0UL /\
      S.equal (as_seq h1 rv) S.empty))
let create_reserve #a rg len rid =
  V.create_reserve len (Rgl?.dummy rg) rid

val create:
  #a:Type0 -> rg:regional a ->
  len:uint64_t{len > 0UL} ->
  HST.ST (rvector rg)
    (requires (fun h0 -> true))
    (ensures (fun h0 rv h1 ->
      modifies (V.loc_vector rv) h0 h1 /\
      rv_inv h1 rv /\
      MHS.fresh_region (V.frameOf rv) h0 h1 /\
      V.size_of rv = len /\
      V.forall_all h1 rv (fun r -> Rgl?.r_init_p rg r) /\
      S.equal (as_seq h1 rv)
      	      (S.create (U64.v len) (Ghost.reveal (Rgl?.irepr rg)))))
let create #a rg len =
  let nrid = new_region_ HH.root in
  create_rid rg len nrid

val insert:
  #a:Type0 -> #rg:regional a ->
  rv:rvector rg{not (V.is_full rv)} -> v:a ->
  HST.ST (rvector rg)
    (requires (fun h0 ->
      rv_inv h0 rv /\ Rgl?.r_inv rg h0 v /\
      HH.extends (Rgl?.region_of rg v) (V.frameOf rv) /\
      V.forall_all h0 rv
	(fun b -> HH.disjoint (Rgl?.region_of rg b)
			      (Rgl?.region_of rg v))))
    (ensures (fun h0 irv h1 ->
      V.size_of irv = V.size_of rv + 1UL /\
      V.frameOf rv = V.frameOf irv /\
      modifies (loc_union (V.loc_addr_of_vector rv)
			  (V.loc_vector irv)) h0 h1 /\
      rv_inv h1 irv /\
      V.get h1 irv (V.size_of rv) == v /\
      S.equal (as_seq h1 irv)
      	      (S.snoc (as_seq h0 rv) (Rgl?.r_repr rg h0 v))))
#reset-options "--z3rlimit 40"
let insert #a #rg rv v =
  let hh0 = HST.get () in
  let irv = V.insert rv v in
  let hh1 = HST.get () in

  // Safety
  rs_loc_elems_parent_disj
    rg (V.as_seq hh0 rv) (V.frameOf rv) 0 (U64.v (V.size_of rv));
  rs_elems_inv_preserved
    rg (V.as_seq hh0 rv) 0 (U64.v (V.size_of rv))
    (loc_region_only false (V.frameOf rv))
    hh0 hh1;
  Rgl?.r_sep rg v
    (loc_region_only false (V.frameOf rv))
    hh0 hh1;

  // Correctness
  assert (S.equal (V.as_seq hh0 rv)
  		  (S.slice (V.as_seq hh1 irv) 0 (U64.v (V.size_of rv))));
  as_seq_seq_preserved
    rg (V.as_seq hh0 rv)
    0 (U64.v (V.size_of rv))
    (loc_region_only false (V.frameOf rv)) hh0 hh1;
  as_seq_seq_slice
    rg hh1 (V.as_seq hh1 irv) 0 (U64.v (V.size_of irv))
    0 (U64.v (V.size_of rv));
  irv

val insert_copy:
  #a:Type0 -> #rg:regional a -> cp:copyable a rg ->
  rv:rvector rg{not (V.is_full rv)} -> v:a ->
  HST.ST (rvector rg)
    (requires (fun h0 ->
      rv_inv h0 rv /\ Rgl?.r_inv rg h0 v /\
      HH.disjoint (Rgl?.region_of rg v) (V.frameOf rv)))
    (ensures (fun h0 irv h1 ->
      V.size_of irv = V.size_of rv + 1UL /\
      V.frameOf rv = V.frameOf irv /\
      modifies (loc_rvector rv) h0 h1 /\
      rv_inv h1 irv /\
      S.equal (as_seq h1 irv)
      	      (S.snoc (as_seq h0 rv) (Rgl?.r_repr rg h0 v))))
let insert_copy #a #rg cp rv v =
  let hh0 = HST.get () in
  rv_elems_inv_live_region hh0 rv 0UL (V.size_of rv);
  let nrid = new_region_ (V.frameOf rv) in
  let nv = Rgl?.r_init rg nrid in

  let hh1 = HST.get () in
  Rgl?.r_sep rg v loc_none hh0 hh1;
  rv_inv_preserved rv loc_none hh0 hh1;
  as_seq_preserved rv loc_none hh0 hh1;
  let copy = Cpy?.copy cp in
  copy v nv;

  let hh2 = HST.get () in
  rv_loc_elems_each_disj hh2 rv 0UL (V.size_of rv) nrid;
  rv_inv_preserved_ rv (loc_all_regions_from false nrid) hh1 hh2;
  as_seq_preserved_ rv (loc_all_regions_from false nrid) hh1 hh2;
  insert rv nv

val assign:
  #a:Type0 -> #rg:regional a -> rv:rvector rg ->
  i:uint64_t{i < V.size_of rv} -> v:a ->
  HST.ST unit
    (requires (fun h0 ->
      // rv_inv h0 rv /\
      rv_itself_inv h0 rv /\
      rv_elems_inv h0 rv 0UL i /\
      rv_elems_inv h0 rv (i + 1UL) (V.size_of rv) /\
      elems_reg h0 rv /\

      V.forall_ h0 rv 0UL i
	(fun b -> HH.disjoint (Rgl?.region_of rg b)
			      (Rgl?.region_of rg v)) /\
      V.forall_ h0 rv (i + 1UL) (V.size_of rv)
      	(fun b -> HH.disjoint (Rgl?.region_of rg b)
      			      (Rgl?.region_of rg v)) /\
      Rgl?.r_inv rg h0 v /\
      HH.extends (Rgl?.region_of rg v) (V.frameOf rv)))
    (ensures (fun h0 _ h1 ->
      modifies (V.loc_vector_within rv i (i + 1UL)) h0 h1 /\
      rv_inv h1 rv /\
      V.get h1 rv i == v /\
      S.equal (as_seq h1 rv)
	      (S.append
		(as_seq_sub h0 rv 0UL i)
		(S.cons (Rgl?.r_repr rg h0 v)
		  (as_seq_sub h0 rv (i + 1UL) (V.size_of rv))))))
let assign #a #rg rv i v =
  let hh0 = HST.get () in
  V.assign rv i v;
  let hh1 = HST.get () in

  // Safety
  rs_loc_elems_parent_disj
    rg (V.as_seq hh0 rv) (V.frameOf rv) 0 (U64.v i);
  rs_loc_elems_parent_disj
    rg (V.as_seq hh0 rv) (V.frameOf rv) (U64.v i + 1) (U64.v (V.size_of rv));
  rs_elems_inv_preserved
    rg (V.as_seq hh0 rv) 0 (U64.v i)
    (V.loc_vector rv)
    hh0 hh1;
  rs_elems_inv_preserved
    rg (V.as_seq hh0 rv) (U64.v i + 1) (U64.v (V.size_of rv))
    (V.loc_vector rv)
    hh0 hh1;
  Rgl?.r_sep rg v (V.loc_vector rv) hh0 hh1;

  // Correctness
  rs_loc_elems_parent_disj
    rg (V.as_seq hh1 rv) (V.frameOf rv) 0 (U64.v (V.size_of rv));
  as_seq_seq_preserved
    rg (V.as_seq hh1 rv)
    0 (U64.v (V.size_of rv))
    (V.loc_vector rv) hh0 hh1

private val r_sep_forall:
  #a:Type0 -> rg:regional a ->
  p:loc -> h0:HS.mem -> h1:HS.mem ->
  v:a{Rgl?.r_inv rg h0 v} ->
  Lemma (requires (loc_disjoint (loc_all_regions_from
				  false (Rgl?.region_of rg v)) p /\
		  modifies p h0 h1))
	(ensures (Rgl?.r_inv rg h1 v /\
		 Rgl?.r_repr rg h0 v == Rgl?.r_repr rg h1 v))
private let r_sep_forall #a rg p h0 h1 v =
  Rgl?.r_sep rg v p h0 h1

val assign_copy:
  #a:Type0 -> #rg:regional a -> cp:copyable a rg ->
  rv:rvector rg ->
  i:uint64_t{i < V.size_of rv} -> v:a ->
  HST.ST unit
    (requires (fun h0 ->
      rv_inv h0 rv /\
      Rgl?.r_inv rg h0 v /\
      HH.disjoint (Rgl?.region_of rg v) (V.frameOf rv)))
    (ensures (fun h0 _ h1 ->
      modifies (loc_all_regions_from
	         false (Rgl?.region_of rg (V.get h1 rv i))) h0 h1 /\
      rv_inv h1 rv /\
      S.equal (as_seq h1 rv)
      	      (S.upd (as_seq h0 rv) (U64.v i) (Rgl?.r_repr rg h0 v))))
let assign_copy #a #rg cp rv i v =
  let hh0 = HST.get () in
  let copy = Cpy?.copy cp in
  copy v (V.index rv i);
  let hh1 = HST.get () in

  // Safety
  rv_inv_preserved_int #a #rg rv i hh0 hh1;

  // Correctness
  forall_intro
    (move_requires
      (rs_loc_elem_disj
  	rg (V.as_seq hh0 rv) (V.frameOf rv)
  	0 (U64.v (V.size_of rv))
  	(U64.v i)));
  assert (forall (k:nat{k <> U64.v i && k < U64.v (V.size_of rv)}).
  	   loc_disjoint (rs_loc_elem rg (V.as_seq hh0 rv) k)
  			(rs_loc_elem rg (V.as_seq hh0 rv) (U64.v i)));
  forall_intro
    (move_requires
      (r_sep_forall
  	rg (rs_loc_elem rg (V.as_seq hh0 rv) (U64.v i))
  	hh0 hh1));
  assert (forall (k:nat{k <> U64.v i && k < U64.v (V.size_of rv)}).
  	   loc_disjoint (rs_loc_elem rg (V.as_seq hh0 rv) k)
  			(rs_loc_elem rg (V.as_seq hh0 rv) (U64.v i)) ==>
  	   Rgl?.r_repr rg hh1 (S.index (V.as_seq hh1 rv) k) ==
  	   Rgl?.r_repr rg hh0 (S.index (V.as_seq hh0 rv) k));
  assert (forall (k:nat{k <> U64.v i && k < U64.v (V.size_of rv)}).
  	   Rgl?.r_repr rg hh1 (S.index (V.as_seq hh1 rv) k) ==
  	   Rgl?.r_repr rg hh0 (S.index (V.as_seq hh0 rv) k));
  assert (forall (k:nat{k <> U64.v i && k < U64.v (V.size_of rv)}).
  	   S.index (as_seq_seq rg hh1 (V.as_seq hh1 rv)
  			       0 (U64.v (V.size_of rv))) k ==
  	   S.index (as_seq_seq rg hh0 (V.as_seq hh0 rv)
  			       0 (U64.v (V.size_of rv))) k)

val free_elems:
  #a:Type0 -> #rg:regional a -> rv:rvector rg ->
  idx:uint64_t{idx < V.size_of rv} ->
  HST.ST unit
    (requires (fun h0 ->
      V.live h0 rv /\
        rv_elems_inv h0 rv 0UL (idx + 1UL) /\
        rv_elems_reg h0 rv 0UL (idx + 1UL)))
    (ensures (fun h0 _ h1 ->
      idx < V.size_of rv ==> modifies (rv_loc_elems h0 rv 0UL (idx + 1UL)) h0 h1))
let rec free_elems #a #rg rv idx =
  let hh0 = HST.get () in
    Rgl?.r_free rg (V.index rv idx);

    let hh1 = HST.get () in
    rs_loc_elems_elem_disj
      rg (V.as_seq hh0 rv) (V.frameOf rv)
      0 (U64.v idx + 1) 0 (U64.v idx) (U64.v idx);
    rv_elems_inv_preserved
      rv 0UL idx (rs_loc_elem rg (V.as_seq hh0 rv) (U64.v idx)) hh0 hh1;

    if idx <> 0UL then
      free_elems rv (idx - 1UL)

val flush:
  #a:Type0 -> #rg:regional a ->
  rv:rvector rg -> i:uint64_t{i <= V.size_of rv} ->
  HST.ST (rvector rg)
    (requires (fun h0 -> rv_inv h0 rv))
    (ensures (fun h0 frv h1 ->
      V.size_of frv = V.size_of rv - i /\
      V.frameOf rv = V.frameOf frv /\
      modifies (loc_rvector rv) h0 h1 /\
      rv_inv h1 frv /\
      S.equal (as_seq h1 frv)
      	      (S.slice (as_seq h0 rv) (U64.v i) (U64.v (V.size_of rv)))))
#reset-options "--z3rlimit 40"
let flush #a #rg rv i =
  let hh0 = HST.get () in
  (if i = 0UL then () else free_elems rv (i - 1UL));
  rv_loc_elems_included hh0 rv 0UL i;

  let hh1 = HST.get () in
  assert (modifies (rs_loc_elems rg (V.as_seq hh0 rv) 0 (U64.v i)) hh0 hh1);
  let frv = V.flush rv (Rgl?.dummy rg) i in

  let hh2 = HST.get () in
  assert (modifies (loc_region_only false (V.frameOf rv)) hh1 hh2);

  // Safety
  rs_loc_elems_disj
    rg (V.as_seq hh0 rv) (V.frameOf rv) 0 (U64.v (V.size_of rv))
    0 (U64.v i) (U64.v i) (U64.v (V.size_of rv));
  rs_loc_elems_parent_disj
    rg (V.as_seq hh0 rv) (V.frameOf rv)
    (U64.v i) (U64.v (V.size_of rv));
  rs_elems_inv_preserved
    rg (V.as_seq hh0 rv) (U64.v i) (U64.v (V.size_of rv))
    (loc_union (rs_loc_elems rg (V.as_seq hh0 rv) 0 (U64.v i))
	       (loc_region_only false (V.frameOf rv)))
    hh0 hh2;
  assert (rv_inv #a #rg hh2 frv);

  // Correctness
  as_seq_seq_preserved
    rg (V.as_seq hh0 rv) (U64.v i) (U64.v (V.size_of rv))
    (loc_union (rs_loc_elems rg (V.as_seq hh0 rv) 0 (U64.v i))
  	       (loc_region_only false (V.frameOf rv)))
    hh0 hh2;
  as_seq_seq_slice
    rg hh0 (V.as_seq hh0 rv) 0 (U64.v (V.size_of rv))
    (U64.v i) (U64.v (V.size_of rv));
  assert (S.equal (S.slice (as_seq hh0 rv) (U64.v i) (U64.v (V.size_of rv)))
		  (as_seq_seq rg hh2 (V.as_seq hh0 rv)
		    (U64.v i) (U64.v (V.size_of rv))));
  as_seq_seq_eq
    rg hh2 (V.as_seq hh0 rv) (V.as_seq hh2 frv)
    (U64.v i) (U64.v (V.size_of rv)) 0 (U64.v (V.size_of frv));
  assert (S.equal (as_seq_seq rg hh2 (V.as_seq hh2 frv)
		    0 (U64.v (V.size_of frv)))
		  (as_seq_seq rg hh2 (V.as_seq hh0 rv)
		    (U64.v i) (U64.v (V.size_of rv))));
  assert (S.equal (S.slice (as_seq hh0 rv) (U64.v i) (U64.v (V.size_of rv)))
		  (as_seq hh2 frv));
  frv

val free:
  #a:Type0 -> #rg:regional a -> rv:rvector rg ->
  HST.ST unit
    (requires (fun h0 -> rv_inv h0 rv))
    (ensures (fun h0 _ h1 -> modifies (loc_rvector rv) h0 h1))
let free #a #rg rv =
  let hh0 = HST.get () in
  (if V.size_of rv = 0UL then ()
  else free_elems rv (V.size_of rv - 1UL));
  let hh1 = HST.get () in
  rv_loc_elems_included hh0 rv 0UL (V.size_of rv);
  V.free rv
