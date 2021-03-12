module Primitive where

import Prelude hiding (absurd, apply)
import Data.Either (Either(..))
import Data.Foldable (foldl)
import Data.Int (ceil, floor, toNumber)
import Data.List (List(..), (:))
import Data.Map (Map, fromFoldable)
import Data.Profunctor.Choice ((|||))
import Data.Tuple (fst)
import Debug.Trace (trace)
import Math (log, pow)
import Text.Parsing.Parser.Expr (Assoc(..))
import Bindings (Bindings(..), Var, (:+:), (↦))
import DataType (cCons, cFalse, cPair, cTrue)
import Lattice (𝔹, (∧))
import Util (type (×), (×), type (+), (!), absurd, error, unsafeUpdateAt)
import Val (Env, MatrixRep, PrimOp(..), Val(..))

-- name in user land, precedence 0 from 9 (similar from Haskell 98), associativity
type OpDef = {
   op    :: Var,
   prec  :: Int,
   assoc :: Assoc
}

opDef :: Var -> Int -> Assoc -> Var × OpDef
opDef op prec assoc = op × { op, prec, assoc }

-- Syntactic information only. No guarantee that any of these will be defined.
opDefs :: Map String OpDef
opDefs = fromFoldable [
   opDef "!"   8 AssocLeft,
   opDef "**"  8 AssocRight,
   opDef "*"   7 AssocLeft,
   opDef "/"   7 AssocLeft,
   opDef "+"   6 AssocLeft,
   opDef "-"   6 AssocLeft,
   opDef ":"   6 AssocRight,
   opDef "++"  5 AssocRight,
   opDef "=="  4 AssocNone,
   opDef "/="  4 AssocNone,
   opDef "<"   4 AssocLeft,
   opDef ">"   4 AssocLeft,
   opDef "<="  4 AssocLeft,
   opDef ">="  4 AssocLeft
]

class From a where
   from :: Val 𝔹 -> a × 𝔹          -- only defined for non-holes
   expand :: a -> Val 𝔹            -- use just enough information from supplied value to construct an argument to 'from'

from_fwd :: forall a . From a => Val 𝔹 × a -> a × 𝔹
from_fwd (Hole × v') = from (expand v')
from_fwd (v × _)     = from v

class To a where
   to :: a × 𝔹 -> Val 𝔹

-- REVISIT: These two are a bit weird. Former is only needed for debugLog, latter for debugLog and matrix lookup.
instance fromVal :: From (Val Boolean) where
   from = (_ × false)
   expand = identity

-- Return value is already a Val, then it's not being constructed.
instance toVal :: To (Val Boolean) where
   to = fst

instance fromInt :: From Int where
   from (Int α n)   = n × α
   from _           = error "Int expected"

   expand = Int false

instance toInt :: To Int where
   to (n × α) = Int α n

instance fromNumber :: From Number where
   from (Float α n) = n × α
   from _           = error "Float expected"

   expand = Float false

instance toNumber :: To Number where
   to (n × α) = Float α n

instance fromString :: From String where
   from (Str α str) = str × α
   from _           = error "Str expected"

   expand = Str false

instance toString :: To String where
   to (str × α) = Str α str

instance fromIntOrNumber :: From (Int + Number) where
   from (Int α n)    = Left n × α
   from (Float α n)  = Right n × α
   from _            = error "Int or Float expected"

   expand (Left n)  = Int false n
   expand (Right n) = Float false n

instance toIntOrNumber :: To (Int + Number) where
   to (Left n × α)    = Int α n
   to (Right n × α)   = Float α n

instance fromIntOrNumberOrString :: From (Either (Either Int Number) String) where
   from (Int α n)   = Left (Left n) × α
   from (Float α n) = Left (Right n) × α
   from (Str α n)   = Right n × α
   from _           = error "Int, Float or Str expected"

   expand (Left (Left n))    = Int false n
   expand (Left (Right n))   = Float false n
   expand (Right str)        = Str false str

instance fromIntAndInt :: From (Int × Boolean × (Int × Boolean)) where
   from (Constr α c (v : v' : Nil)) | c == cPair  = from v × from v' × α
   from _                                         = error "Pair expected"

   expand _ = Constr false cPair (Hole : Hole : Nil)

instance fromMatrixRep :: From (Array (Array (Val Boolean)) × (Int × Boolean) × (Int × Boolean)) where
   from (Matrix α r) = r × α
   from _            = error "Matrix expected"

   expand (vss × (i × _) × (j × _)) = Matrix false (((<$>) (const Hole) <$> vss) × (i × false) × (j × false))

instance toPair :: To (Val Boolean × Val Boolean) where
   to (v × v' × α) = Constr α cPair (v : v' : Nil)

unary' :: forall a b . From a => To b => (a × 𝔹 -> b × 𝔹) -> List (Val 𝔹) -> Val 𝔹
unary' op (v : Nil) = to (op (from v))
unary' _ _          = error absurd

unary_fwd :: forall a b . From a => To b => (a × 𝔹 -> b × 𝔹) -> List (Val 𝔹 × Val 𝔹) -> Val 𝔹
unary_fwd op (v × u : Nil) = to (op (from_fwd (v × fst (from u))))
unary_fwd _ _              = error absurd

binary' :: forall a b c . From a => From b => To c => (a × 𝔹 -> b × 𝔹 -> c × 𝔹) -> List (Val 𝔹) -> Val 𝔹
binary' op (v : vs)   = unary' (op (from v)) vs
binary' _ _           = error absurd

binary_fwd :: forall a b c . From a => From b => To c => (a × 𝔹 -> b × 𝔹 -> c × 𝔹) -> List (Val 𝔹 × Val 𝔹) -> Val 𝔹
binary_fwd op (v × u : vus)   = unary_fwd (op (from_fwd (v × fst (from u)))) vus
binary_fwd _ _                = error absurd

unary :: forall a b . From a => To b => UnarySpec a b -> Val 𝔹
unary (op × op') = flip Primitive Nil $ PrimOp {
   arity: 1,
   op: unary' op,
   op_fwd: unary_fwd op,
   op_bwd: \v vs -> vs
}

binary :: forall a b c . From a => From b => To c => BinarySpec a b c -> Val 𝔹
binary (op × _) = flip Primitive Nil $ PrimOp {
   arity: 2,
   op: binary' op,
   op_fwd: binary_fwd op,
   op_bwd: \_ vs -> vs
}

type UnarySpec a b = (a × 𝔹 -> b × 𝔹) × (b × 𝔹 -> a -> a × 𝔹)
type BinarySpec a b c = (a × 𝔹 -> b × 𝔹 -> c × 𝔹) × (𝔹 -> a × b -> 𝔹 × 𝔹)

depends :: forall a b . (a -> b) -> UnarySpec a b
depends op = fwd × bwd
   where
   fwd (x × α)    = op x × α
   bwd (y × α) x  = x × α

dependsBoth :: forall a b c . (a -> b -> c) -> BinarySpec a b c
dependsBoth op = fwd × bwd
   where
   fwd (x × α) (y × β) = x `op` y × (α ∧ β)
   bwd α _ = α × α

dependsNeither :: forall a b c . (a -> b -> c) -> BinarySpec a b c
dependsNeither op = fwd × bwd
   where
   fwd (x × _) (y × _) = x `op` y × true
   bwd _ _ = false × false

class IsZero a where
   isZero :: a -> Boolean

instance isZeroInt :: IsZero Int where
   isZero = ((==) 0)

instance isZeroNumber :: IsZero Number where
   isZero = ((==) 0.0)

instance isZeroEither :: (IsZero a, IsZero b) => IsZero (a + b) where
   isZero = isZero ||| isZero

-- If both are zero, we depend only on the first.
dependsNonZero :: forall a b . IsZero a => (a -> a -> b) -> BinarySpec a a b
dependsNonZero op = fwd × bwd
   where
   fwd :: a × 𝔹 -> a × 𝔹 -> b × 𝔹
   fwd (x × α) (y × β)
      | isZero x  = x `op` y × α
      | isZero y  = x `op` y × β
      | otherwise = x `op` y × (α ∧ β)
   bwd :: 𝔹 -> a × a -> 𝔹 × 𝔹
   bwd α (x × y)
      | isZero x  = α × false
      | isZero y  = false × α
      | otherwise = α × α

instance fromBoolean :: To Boolean where
   to (true × α)   = Constr α cTrue Nil
   to (false × α)  = Constr α cFalse Nil

primitives :: Env 𝔹
primitives = foldl (:+:) Empty [
   -- some signatures are specified for clarity or from drive instance resolution
   -- PureScript's / and pow aren't defined at Int -> Int -> Number, so roll our own
   ":"         ↦ Constr false cCons Nil,
   "+"         ↦ binary (dependsBoth ((+) `union2` (+))),
   "-"         ↦ binary (dependsBoth ((-) `union2` (-))),
   "*"         ↦ binary (dependsNonZero ((*) `union2` (*))),
   "**"        ↦ binary (dependsNonZero ((\x y -> toNumber x `pow` toNumber y) `union2'` pow)),
   "/"         ↦ binary (dependsNonZero ((\x y -> toNumber x / toNumber y)  `union2'` (/))),
   "=="        ↦ binary (dependsBoth ((==) `union2'` (==) `unionDisj` (==))),
   "/="        ↦ binary (dependsBoth ((/=) `union2'` (/=) `unionDisj` (==))),
   "<"         ↦ binary (dependsBoth ((<)  `union2'` (<)  `unionDisj` (==))),
   ">"         ↦ binary (dependsBoth ((>)  `union2'` (>)  `unionDisj` (==))),
   "<="        ↦ binary (dependsBoth ((<=) `union2'` (<=) `unionDisj` (==))),
   ">="        ↦ binary (dependsBoth ((>=) `union2'` (>=) `unionDisj` (==))),
   "++"        ↦ binary (dependsBoth ((<>) :: String -> String -> String)),
   "!"         ↦ binary (dependsNeither matrixLookup),
   "ceiling"   ↦ unary (depends ceil),
   "debugLog"  ↦ unary (depends debugLog),
   "dims"      ↦ unary (depends dims),
   "div"       ↦ binary (dependsNonZero (div :: Int -> Int -> Int)),
   "error"     ↦ unary (depends  (error :: String -> Boolean)),
   "floor"     ↦ unary (depends floor),
   "log"       ↦ unary (depends ((toNumber >>> log) `union` log)),
   "numToStr"  ↦ unary (depends (show `union` show))
]

debugLog :: Val 𝔹 -> Val 𝔹
debugLog x = trace x (const x)

dims :: MatrixRep 𝔹 -> Val 𝔹 × Val 𝔹
dims (_ × (i × α) × (j × β)) = Int α i × Int β j

dims_bwd :: Val 𝔹 × Val 𝔹 -> MatrixRep 𝔹 -> MatrixRep 𝔹
dims_bwd (Int α i' × Int β j') (vss × (i × _) × (j × _)) | i == i' && j == j' = vss × (i × α) × (j × β)
dims_bwd _ _                                                                  = error absurd

matrixLookup :: MatrixRep 𝔹 -> (Int × 𝔹) × (Int × 𝔹) -> Val 𝔹
matrixLookup (vss × _ × _) ((i × _) × (j × _)) = vss!(i - 1)!(j - 1)

matrixLookup_bwd :: Val 𝔹 -> MatrixRep 𝔹 × (Int × 𝔹) × (Int × 𝔹) -> MatrixRep 𝔹 × (Int × 𝔹) × (Int × 𝔹)
matrixLookup_bwd v ((vss × (i' × _) × (j' × _)) × (i × _) × (j × _)) =
   vss'' × (i' × false) × (j' × false) × (i × false) × (j × false)
   where vss'  = (((<$>) (const Hole)) <$> vss)
         vs_i  = vss'!(i - 1)
         vss'' = unsafeUpdateAt (i - 1) (unsafeUpdateAt (j - 1) (vs_i!(j - 1)) vs_i) vss'

-- Could improve this a bit with some type class shenanigans, but not straightforward.
union :: forall a . (Int -> a) -> (Number -> a) -> Int + Number -> a
union f _ (Left x)   = f x
union _ f (Right x)  = f x

union2 :: (Int -> Int -> Int) -> (Number -> Number -> Number) -> Int + Number -> Int + Number -> Int + Number
union2 f _ (Left x) (Left y)     = Left $ f x y
union2 _ f (Left x) (Right y)    = Right $ f (toNumber x) y
union2 _ f (Right x) (Right y)   = Right $ f x y
union2 _ f (Right x) (Left y)    = Right $ f x (toNumber y)

union2' :: forall a . (Int -> Int -> a) -> (Number -> Number -> a) -> Int + Number -> Int + Number -> a
union2' f _ (Left x) (Left y)    = f x y
union2' _ f (Left x) (Right y)   = f (toNumber x) y
union2' _ f (Right x) (Right y)  = f x y
union2' _ f (Right x) (Left y)   = f x (toNumber y)

unionDisj :: forall a b . (b -> b -> a) -> (String -> String -> a) -> b + String -> b + String -> a
unionDisj f _ (Left x) (Left y)   = f x y
unionDisj _ _ (Left _) (Right _)  = error "Non-uniform argument types"
unionDisj _ f (Right x) (Right y) = f x y
unionDisj _ _ (Right _) (Left _)  = error "Non-uniform argument types"
