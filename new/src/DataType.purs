module DataType where

import Prelude
import Data.Foldable (class Foldable)
import Data.List (List)
import Data.List (fromFoldable) as L
import Data.Map (Map, fromFoldable)
import Data.Newtype (class Newtype, unwrap)
import Data.Tuple (Tuple(..))
import Util (type (×))

newtype Ctr = Ctr String
derive instance newtypeCtr :: Newtype Ctr _
derive instance eqCtr :: Eq Ctr
derive instance ordCtr :: Ord Ctr

instance showCtr :: Show Ctr where
   show = unwrap

data DataType' a = DataType String (Map Ctr a)
type DataType = DataType' CtrSig
data CtrSig = CtrSig Ctr (List String)

ctr :: forall f . Foldable f => Ctr -> f String -> Ctr × CtrSig
ctr c = L.fromFoldable >>> CtrSig c >>> Tuple c

dataType :: forall f . Foldable f => String -> f (Ctr × CtrSig) -> DataType
dataType name = fromFoldable >>> DataType name

-- Bool
cFalse   = Ctr "False"  :: Ctr
cTrue    = Ctr "True"   :: Ctr
-- List
cNil     = Ctr "Nil"    :: Ctr
cCons    = Ctr "Cons"   :: Ctr
-- Pair
cPair    = Ctr "Pair"   :: Ctr

dataTypes :: List DataType
dataTypes = L.fromFoldable [
   dataType "Bool" [
      ctr cTrue [],
      ctr cFalse []
   ],
   dataType "List" [
      ctr cNil [],
      ctr cCons ["head", "tail"]
   ],
   dataType "Pair" [
      ctr cPair ["fst", "snd"]
   ]
]
