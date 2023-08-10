module Graph where

import Prelude hiding (add)

import Control.Monad.Rec.Class (Step(..), tailRecM)
import Control.Monad.ST (ST)
import Data.Foldable (class Foldable, foldl, foldM)
import Data.List (List(..), (:), concat)
import Data.List (fromFoldable) as L
import Data.Maybe (Maybe(..), isJust)
import Data.Newtype (class Newtype, unwrap)
import Data.Profunctor.Strong (first)
import Data.Set (Set)
import Data.Set as S
import Dict (Dict)
import Dict as D
import Foreign.Object (runST)
import Foreign.Object.ST (STObject)
import Foreign.Object.ST as OST
import Util (Endo, (×), type (×), definitely)

type Edge = Vertex × Vertex

-- | Graphs form a semigroup but we don't actually rely on that (for efficiency).
class Monoid g <= Graph g where
   -- add vertex α to g with αs as out neighbours, where each neighbour is already in g.
   -- | add and remove satisfy:
   -- |    remove α (add α αs g) = g
   -- |    add α (outN α g) (remove α g) = g
   add :: Vertex -> Set Vertex -> Endo g

   -- remove a vertex from g.
   remove :: Vertex -> Endo g

   -- addOut α β adds β as new out-neighbour of existing vertex α, adding into g if necessary
   -- | addIn and addOut satisfy
   -- |   addIn α β G = op (addOut β α (op G)
   addOut :: Vertex -> Vertex -> Endo g
   -- | addIn α β adds α as new in-neighbour of existing vertex β, adding into g if necessary
   addIn :: Vertex -> Vertex -> Endo g

   -- | Whether g contains a given vertex.
   elem :: g -> Vertex -> Boolean

   -- | outN and iN satisfy
   -- |   inN G = outN (op G)
   outN :: g -> Vertex -> Set Vertex
   inN :: g -> Vertex -> Set Vertex

   -- | Number of vertices in g.
   size :: g -> Int

   -- |   op (op g) = g
   op :: Endo g

   -- |   Discrete graph consisting only of a set of vertices.
   discreteG :: Set Vertex -> g

   fromFoldable :: forall f. Functor f => Foldable f => f (Vertex × Set Vertex) -> g

newtype Vertex = Vertex String

outEdges' :: forall g. Graph g => g -> Vertex -> List Edge
outEdges' g = inEdges' (op g)

outEdges :: forall g. Graph g => g -> Set Vertex -> List Edge
outEdges g = inEdges (op g)

inEdges' :: forall g. Graph g => g -> Vertex -> List Edge
inEdges' g α = L.fromFoldable $ S.map (_ × α) (inN g α)

inEdges :: forall g. Graph g => g -> Set Vertex -> List Edge
inEdges g αs = concat (inEdges' g <$> L.fromFoldable αs)

derive instance Eq Vertex
derive instance Ord Vertex
derive instance Newtype Vertex _

instance Show Vertex where
   show (Vertex α) = "Vertex " <> α

-- Maintain out neighbours and in neighbours as separate adjacency maps with a common domain.
type AdjMap = Dict (Set Vertex)
data GraphImpl = GraphImpl (AdjMap) (AdjMap)

-- Provided for completeness, but for efficiency we avoid them.
instance Semigroup GraphImpl where
   append (GraphImpl out1 in1) (GraphImpl out2 in2) =
      GraphImpl (D.unionWith S.union out1 out2) (D.unionWith S.union in1 in2)

instance Monoid GraphImpl where
   mempty = GraphImpl D.empty D.empty

empty :: GraphImpl
empty = mempty

instance Graph GraphImpl where
   remove α (GraphImpl out in_) = GraphImpl out' in'
      where
      out' = S.delete α <$> D.delete (unwrap α) out
      in' = S.delete α <$> D.delete (unwrap α) in_

   add α αs (GraphImpl out in_) = GraphImpl out' in'
      where
      out' = D.insert (unwrap α) αs out
      in' = foldl (\d α' -> D.insertWith S.union (unwrap α') (S.singleton α) d)
         (D.insert (unwrap α) S.empty in_)
         αs

   addOut α β (GraphImpl out in_) = GraphImpl out' in'
      where
      out' = D.update (S.insert β >>> Just) (unwrap α)
         (D.insertWith S.union (unwrap β) S.empty out)
      in' = D.insertWith S.union (unwrap β) (S.singleton α) in_

   addIn α β g = op (addOut β α (op g))

   outN (GraphImpl out _) α = D.lookup (unwrap α) out # definitely "in graph"
   inN g = outN (op g)

   elem (GraphImpl out _) α = isJust (D.lookup (unwrap α) out)
   size (GraphImpl out _) = D.size out

   op (GraphImpl out in_) = GraphImpl in_ out

   discreteG αs = GraphImpl discreteM discreteM
      where
      discreteM = D.fromFoldable $ S.map (\α -> unwrap α × S.empty) αs

   fromFoldable α_αs = GraphImpl out in_
      where
      out = D.fromFoldable (α_αs <#> first unwrap)
      in_ = opMap (L.fromFoldable α_αs) -- gratuitous to turn one foldable into another

-- In-place update of mutable object to calculate opposite adjacency map.
type MutableAdjMap r = STObject r (Set Vertex)

opMap :: List (Vertex × Set Vertex) -> AdjMap
opMap α_αs = runST opMap' α_αs

opMap' :: List (Vertex × Set Vertex) -> forall r. ST r (MutableAdjMap r)
opMap' α_αs = do
   in_ <- OST.new
   tailRecM addEdges (α_αs × in_)
   where
   addEdges
      :: List (Vertex × Set Vertex) × MutableAdjMap r
      -> ST r (Step (List (Vertex × Set Vertex) × MutableAdjMap r) (MutableAdjMap r))
   addEdges (Nil × acc) = pure $ Done acc
   addEdges (((α × βs) : rest) × acc) = do
      acc' <- foldM (addEdge α) acc βs
      pure $ Loop (rest × acc')

   addEdge :: Vertex -> MutableAdjMap r -> Vertex -> ST r (MutableAdjMap r)
   addEdge α acc (Vertex β) = do
      αs <- OST.peek β acc <#> case _ of
         Nothing -> S.singleton α
         Just αs -> S.insert α αs
      OST.poke β αs acc

instance Show GraphImpl where
   show (GraphImpl out in_) = "GraphImpl (" <> show out <> " × " <> show in_ <> ")"
