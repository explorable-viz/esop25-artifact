module Graph where

import Prelude

import Data.Foldable (foldl)
import Data.Maybe (Maybe)
import Data.Newtype (class Newtype)
import Data.Set (Set)
import Data.Set (delete, empty, map, singleton, union, unions) as S
import Data.Tuple (Tuple(..), swap)
import Foreign.Object (Object, delete, fromFoldable, lookup, singleton, size, toUnfoldable, unionWith) as O
import Util (Endo, (×), type (×))

class Graph g where
   union :: Vertex -> Set Vertex -> Endo g
   getOutN :: g -> Vertex -> Maybe (Set Vertex)
   getInN :: g -> Vertex -> Maybe (Set Vertex)
   singleton :: Vertex -> Set Vertex -> g
   remove :: Vertex -> Endo g
   opp :: Endo g
   allocate :: g -> Vertex

newtype Vertex = Vertex String

unwrap :: Vertex -> String
unwrap (Vertex string) = string

newtype AnnGraph = AnnGraph (O.Object (Vertex × (Set Vertex)))

newtype GraphImpl = GraphImpl ((O.Object (Set Vertex)) × (O.Object (Set Vertex)))

instance Graph GraphImpl where
   allocate (GraphImpl (inN × _)) = Vertex α
      where
      α = show $ 1 + (O.size inN)
   remove (Vertex α) (GraphImpl (outN × inN)) = let newOutN = map (S.delete (Vertex α)) (O.delete α outN)
                                                    newInN  = map (S.delete (Vertex α)) (O.delete α inN)
                                                   in GraphImpl (newOutN × newInN)  
   union α αs (GraphImpl (outN × inN)) = (GraphImpl (newoutN × newinN))
      where
      newoutN = O.unionWith S.union outN (outStar α αs)
      newinN = O.unionWith S.union inN (inStar α αs)

   getOutN (GraphImpl (outN × _)) (Vertex α) = O.lookup α outN
   getInN (GraphImpl (_ × inN)) (Vertex α) = O.lookup α inN

   singleton α αs = GraphImpl (outStar α αs × inStar α αs)
   opp (GraphImpl (outN × inN)) = GraphImpl (inN × outN)

-- Initial attempts at making stargraphs, using foldl to construct intermediate objects
outStar :: Vertex -> Set Vertex -> O.Object (Set Vertex)
outStar (Vertex α) αs = foldl (O.unionWith S.union) (O.singleton α αs) (S.map (\(Vertex α') -> O.singleton α' S.empty) αs)

inStar :: Vertex -> Set Vertex -> O.Object (Set Vertex)
inStar (Vertex α) αs = foldl (O.unionWith S.union) (O.singleton α S.empty) (S.map (\(Vertex α') -> O.singleton α' (S.singleton (Vertex α))) αs)

-- prototype attempts at more efficiently implementing the above operations
outStar' :: Vertex -> Set Vertex -> O.Object (Set Vertex)
outStar' v@(Vertex α) αs = O.unionWith S.union (O.singleton α αs) (star' v αs)

star' :: Vertex -> Set Vertex -> O.Object (Set Vertex)
star' (Vertex α) αs = O.fromFoldable $ S.map (\α' -> α × (S.singleton α')) αs
star'' :: Vertex -> Set Vertex -> O.Object (Set Vertex)
star'' α αs = O.fromFoldable $ S.map (\(Vertex α') -> α' × (S.singleton α)) αs

inStar' :: Vertex -> Set Vertex -> O.Object (Set Vertex)
inStar' v@(Vertex α) αs = O.unionWith S.union (O.singleton α S.empty) (star'' v αs)

allEdges :: GraphImpl -> Set (Vertex × Vertex)
allEdges (GraphImpl (obj × _)) = let out = (map adjEdges (O.toUnfoldable obj :: Array (String × (Set Vertex)))) in S.unions out

adjEdges :: Tuple String (Set Vertex) -> Set (Vertex × Vertex)
adjEdges (Tuple id αs) = adjEdges' (Vertex id) αs

adjEdges' :: Vertex -> Set Vertex -> Set (Vertex × Vertex)
adjEdges' v αs = S.map (\node -> (v × node)) αs

reverseEdges :: Endo (Set (Vertex × Vertex))
reverseEdges edges = S.map swap edges

-- fromEdges :: Set (Vertex × Vertex) -> GraphImpl
-- fromEdges edges = GraphImpl $
--    O.fromFoldableWith S.union (S.map (\pair -> (unwrap (fst pair)) × (S.singleton $ snd pair)) edges)

-- instance Foldable Graph where
--     foldl f z (Graph o) = Graph (foldl f z (map fst (O.values o) :: ?_))
--     foldr f z (Graph o) = Graph (foldr f z o)
--     foldMap f (Graph o) = Graph (foldMap f o)

derive instance Eq Vertex
derive instance Ord Vertex
derive instance Newtype Vertex _
