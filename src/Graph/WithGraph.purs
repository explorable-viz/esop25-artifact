module Graph.WithGraph where

import Prelude hiding (map)

import Control.Monad.Except (class MonadError)
import Control.Monad.State (StateT, evalStateT, mapStateT, modify, modify_, runStateT)
import Control.Monad.Trans.Class (lift)
import Data.Identity (Identity)
import Data.List (List(..), range, (:))
import Data.Newtype (unwrap)
import Data.Profunctor.Strong (second)
import Data.Set (Set)
import Data.Set as Set
import Data.Set.NonEmpty (NonEmptySet)
import Data.Traversable (class Traversable, traverse)
import Effect.Exception (Error)
import Graph (class Graph, Vertex(..), HyperEdge, fromEdgeList, showGraph, toEdgeList)
import Lattice (Raw)
import Test.Util.Debug (checking, tracing)
import Util (type (×), assertWhen, spyWhen, (×))

class Monad m <= MonadWithGraph m where
   -- Extend graph with existing vertex pointing to set of existing vertices.
   extend :: Vertex -> NonEmptySet Vertex -> m Unit

class Monad m <= MonadAlloc m where
   fresh :: m Vertex

-- Fix exceptions at Error, the type of JavaScript exceptions, because Aff requires Error, and
-- I can't see a way to convert MonadError Error m (for example) to MonadError Error m.
class (MonadAlloc m, MonadError Error m, MonadWithGraph m) <= MonadWithGraphAlloc m where
   -- Extend with a freshly allocated vertex.
   new :: NonEmptySet Vertex -> m Vertex

-- List of adjacency map entries to serve as a fromFoldable input.
type AdjMapEntries = List HyperEdge
type AllocT m = StateT Int m
type Alloc = AllocT Identity
type WithGraphAllocT m = AllocT (WithGraphT m)
type WithGraphT = StateT AdjMapEntries
type WithGraph = WithGraphT Identity

instance Monad m => MonadAlloc (AllocT m) where
   fresh = do
      n <- modify $ (+) 1
      pure (Vertex $ show n)

instance MonadError Error m => MonadWithGraphAlloc (WithGraphAllocT m) where
   new αs = do
      α <- fresh
      extend α αs
      pure α

instance Monad m => MonadWithGraph (WithGraphT m) where
   extend α αs =
      void $ modify_ $ (:) (α × αs)

instance Monad m => MonadWithGraph (WithGraphAllocT m) where
   extend α = lift <<< extend α

alloc :: forall m t. MonadAlloc m => Traversable t => Raw t -> m (t Vertex)
alloc = traverse (const fresh)

runAllocT :: forall m a. Monad m => Int -> AllocT m a -> m (Int × Set Vertex × a)
runAllocT n m = do
   a × n' <- runStateT m n
   -- TODO: duplicated vertex construction should be avoidable
   let fresh_αs = Set.fromFoldable $ (Vertex <<< show) <$> range (n + 1) n'
   pure (n' × fresh_αs × a)

runAlloc :: forall a. Int -> Alloc a -> Int × Set Vertex × a
runAlloc n = runAllocT n >>> unwrap

runWithGraphT :: forall g m a. Monad m => Graph g => WithGraphT m a -> m (a × g)
runWithGraphT m = runStateT m Nil <#> second fromEdgeList

runWithGraph :: forall g a. Graph g => WithGraph a -> a × g
runWithGraph = runWithGraphT >>> unwrap

runWithGraphAllocT :: forall g m a. Monad m => Graph g => Int -> WithGraphAllocT m a -> m ((g × Int) × a)
runWithGraphAllocT n m = do
   (n' × _ × a) × edges <- runStateT (runAllocT n m) Nil
   let g = fromEdgeList edges
   -- comparing edge lists requires sorting, and causes stack overflow on large graph
   assertWhen checking.edgeListIso (\_ -> g == fromEdgeList (toEdgeList g)) $
      pure ((spyWhen tracing.graphCreation "runWithGraphAllocT" showGraph g × n') × a)

wibble :: forall m a. Monad m => WithGraphAllocT m a -> AllocT m a
wibble = mapStateT (flip evalStateT Nil)
{-
wibble' :: forall g m a. Monad m => Graph g => WithGraphAllocT m a -> AllocT m (g × a)
wibble' m = do
   let q = ?_ :: WithGraphT m (a × Int) -> m ((g × a) × Int)
   mapStateT q m
-}
