module Spec.Lib.IntTypes

(* Declared in .fsti : intsize, bits, maxint *)
#set-options "--z3rlimit 10 --max_fuel 0"

let uint_t (t:inttype) : Type0 = 
  match t with
  | U8 -> UInt8.t
  | U16 -> UInt16.t
  | U32 -> UInt32.t
  | U64 -> UInt64.t
  | U128 -> UInt128.t

let uint_to_nat_ #t (x:uint_t t) = 
  match t with
  | U8 -> UInt8.v x
  | U16 -> UInt16.v x
  | U32 -> UInt32.v x
  | U64 -> UInt64.v x
  | U128 -> UInt128.v x

let uint_v #t u = uint_to_nat_ u

(* Declared in .fsti: uint8, uint16, uint32, uint64, uint128 *)

let u8 x : uint8  = UInt8.uint_to_t x 

let u8uy x = x
  
let u16 x : uint16 = UInt16.uint_to_t x

let u32 x : uint32 = UInt32.uint_to_t x

let u64 x : uint64 = UInt64.uint_to_t x

let u128 x : uint128 = UInt128.uint_to_t x

let uint_to_nat #t u = uint_to_nat_ u
let nat_to_uint #t x : uint_t t = 
  match t with
  | U8 -> u8 x
  | U16 -> u16 x
  | U32 -> u32 x
  | U64 -> u64 x
  | U128 -> u128 x

let cast #t t' u  = 
  let n = uint_to_nat #t u in
  let n' = n % (pow2 (bits t')) in
  nat_to_uint #t' n'
  
let add_mod #t a b =
  match t with
  | U8  -> (UInt8.add_mod a b)
  | U16 -> (UInt16.add_mod a b)
  | U32 -> (UInt32.add_mod a b)
  | U64 -> (UInt64.add_mod a b)
  | U128 -> (UInt128.add_mod a b)
  

let add #t a b = 
  match t with
  | U8 -> (UInt8.add a b)
  | U16 -> (UInt16.add a b)
  | U32 -> (UInt32.add a b)
  | U64 -> (UInt64.add a b)
  | U128 -> (UInt128.add a b)

let incr #t a = 
  match t with
  | U8 -> (UInt8.add a 0x1uy)
  | U16 -> (UInt16.add a 0x1us)
  | U32 -> (UInt32.add a 0x1ul)
  | U64 -> (UInt64.add a 0x1uL)
  | U128 -> (UInt128.add a (UInt128.uint_to_t 1))



let mul_mod #t a b = 
  match t with
  | U8 -> (UInt8.mul_mod a b)
  | U16 -> (UInt16.mul_mod a b)
  | U32 -> (UInt32.mul_mod a b)
  | U64 -> (UInt64.mul_mod a b)


let mul #t a b = 
  match t with
  | U8 -> (UInt8.mul a b)
  | U16 -> (UInt16.mul a b)
  | U32 -> (UInt32.mul a b)
  | U64 -> (UInt64.mul a b)


let sub_mod #t a b = 
  match t with
  | U8 -> (UInt8.sub_mod a b)
  | U16 -> (UInt16.sub_mod a b)
  | U32 -> (UInt32.sub_mod a b)
  | U64 -> (UInt64.sub_mod a b)
  | U128 -> (UInt128.sub_mod a b)


let sub #t a b = 
  match t with
  | U8 -> (UInt8.sub a b)
  | U16 -> (UInt16.sub a b)
  | U32 -> (UInt32.sub a b)
  | U64 -> (UInt64.sub a b)
  | U128 -> (UInt128.sub a b)

let decr #t a = 
  match t with
  | U8 -> (UInt8.sub a 0x1uy)
  | U16 -> (UInt16.sub a 0x1us)
  | U32 -> (UInt32.sub a 0x1ul)
  | U64 -> (UInt64.sub a 0x1uL)
  | U128 -> (UInt128.sub a (UInt128.uint_to_t 1))

let logxor #t a b = 
  match t with
  | U8 -> (UInt8.logxor a b)
  | U16 -> (UInt16.logxor a b)
  | U32 -> (UInt32.logxor a b)
  | U64 -> (UInt64.logxor a b)
  | U128 -> (UInt128.logxor a b)


let logand #t a b = 
  match t with
  | U8 -> (UInt8.logand a b)
  | U16 -> (UInt16.logand a b)
  | U32 -> (UInt32.logand a b)
  | U64 -> (UInt64.logand a b)
  | U128 -> (UInt128.logand a b)


let logor #t a b = 
  match t with
  | U8 -> (UInt8.logor a b)
  | U16 -> (UInt16.logor a b)
  | U32 -> (UInt32.logor a b)
  | U64 -> (UInt64.logor a b)
  | U128 -> (UInt128.logor a b)


let lognot #t a = 
  match t with
  | U8 -> (UInt8.lognot a)
  | U16 -> (UInt16.lognot a)
  | U32 -> (UInt32.lognot a)
  | U64 -> (UInt64.lognot a)
  | U128 -> (UInt128.lognot a)


let shift_right #t a b = 
  match t with
  | U8 -> (UInt8.shift_right a b)
  | U16 -> (UInt16.shift_right a b)
  | U32 -> (UInt32.shift_right a b)
  | U64 -> (UInt64.shift_right a b)
  | U128 -> (UInt128.shift_right a b)


let shift_left #t a b = 
  match t with
  | U8 -> (UInt8.shift_left a b)
  | U16 -> (UInt16.shift_left a b)
  | U32 -> (UInt32.shift_left a b)
  | U64 -> (UInt64.shift_left a b)
  | U128 -> (UInt128.shift_left a b)


let rotate_right #t a b = 
  (logor (shift_right a b)  (shift_left a (sub #U32 (u32 (bits t)) b)))

let rotate_left #t a b = 
  (logor (shift_left a b)  (shift_right a (sub #U32 (u32 (bits t)) b)))

let eq_mask #t a b = 
  match t with
  | U8 -> if FStar.UInt8.(a =^ b) then (u8 (maxint U8)) else (u8 0)
  | U16 -> if FStar.UInt16.(a =^ b) then (u16 (maxint U16)) else (u16 0)
  | U32 -> if FStar.UInt32.(a =^ b) then (u32 (maxint U32)) else (u32 0) 
  | U64 -> if FStar.UInt64.(a =^ b) then (u64 (maxint U64)) else (u64 0) 
  | U128 -> if FStar.UInt128.(a =^ b) then (u128 (maxint U128)) else (u128 0)

let neq_mask #t a b = 
  match t with
  | U8 -> if not FStar.UInt8.(a =^ b) then (u8 (maxint U8)) else (u8 0)
  | U16 -> if not FStar.UInt16.(a =^ b) then (u16 (maxint U16)) else (u16 0)
  | U32 -> if not FStar.UInt32.(a =^ b) then (u32 (maxint U32)) else (u32 0) 
  | U64 -> if not FStar.UInt64.(a =^ b) then (u64 (maxint U64)) else (u64 0) 
  | U128 -> if not FStar.UInt128.(a =^ b) then (u128 (maxint U128)) else (u128 0)

let gte_mask #t a b = 
  match t with
  | U8 -> if FStar.UInt8.(a >=^ b) then (u8 (maxint U8)) else (u8 0)
  | U16 -> if FStar.UInt16.(a >=^ b) then (u16 (maxint U16)) else (u16 0)
  | U32 -> if FStar.UInt32.(a >=^ b) then (u32 (maxint U32)) else (u32 0) 
  | U64 -> if FStar.UInt64.(a >=^ b) then (u64 (maxint U64)) else (u64 0) 
  | U128 -> if FStar.UInt128.(a >=^ b) then (u128 (maxint U128)) else (u128 0)

let gt_mask #t a b = 
  match t with
  | U8 -> if FStar.UInt8.(a >^ b) then (u8 (maxint U8)) else (u8 0)
  | U16 -> if FStar.UInt16.(a >^ b) then (u16 (maxint U16)) else (u16 0)
  | U32 -> if FStar.UInt32.(a >^ b) then (u32 (maxint U32)) else (u32 0) 
  | U64 -> if FStar.UInt64.(a >^ b) then (u64 (maxint U64)) else (u64 0) 
  | U128 -> if FStar.UInt128.(a >^ b) then (u128 (maxint U128)) else (u128 0)


let lt_mask #t a b = 
  match t with
  | U8 -> if FStar.UInt8.(a <^ b) then (u8 (maxint U8)) else (u8 0)
  | U16 -> if FStar.UInt16.(a <^ b) then (u16 (maxint U16)) else (u16 0)
  | U32 -> if FStar.UInt32.(a <^ b) then (u32 (maxint U32)) else (u32 0) 
  | U64 -> if FStar.UInt64.(a <^ b) then (u64 (maxint U64)) else (u64 0) 
  | U128 -> if FStar.UInt128.(a <^ b) then (u128 (maxint U128)) else (u128 0)

let lte_mask #t a b = 
  match t with
  | U8 -> if FStar.UInt8.(a <=^ b) then (u8 (maxint U8)) else (u8 0)
  | U16 -> if FStar.UInt16.(a <=^ b) then (u16 (maxint U16)) else (u16 0)
  | U32 -> if FStar.UInt32.(a <=^ b) then (u32 (maxint U32)) else (u32 0) 
  | U64 -> if FStar.UInt64.(a <=^ b) then (u64 (maxint U64)) else (u64 0) 
  | U128 -> if FStar.UInt128.(a <=^ b) then (u128 (maxint U128)) else (u128 0)
 
(* defined in .fsti: notations +^, -^, ...*)

let size_to_uint32 x = u32 x
let size_incr x = x + 1
let size_decr y = y - 1


type bignum = nat
let bn_v n = n
let bn n = n
let bn_add a b = a + b
let bn_mul a b = a `op_Multiply` b
let bn_sub a b = a - b
let bn_mod a b = a % b
let bn_div a b = a / b


  


