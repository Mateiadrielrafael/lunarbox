module Lunarbox.Data.Graph where

import Prelude
import Control.MonadZero (guard)
import Data.Argonaut (class DecodeJson, class EncodeJson)
import Data.Array (foldr)
import Data.Array as Array
import Data.Array as Foldable
import Data.Bifunctor (lmap, rmap)
import Data.Filterable (filter, filterMap)
import Data.Foldable (class Foldable, foldMap, foldlDefault, foldrDefault)
import Data.Functor (voidLeft)
import Data.Graph as CG
import Data.Lens (lens, wander)
import Data.Lens.At (class At)
import Data.Lens.Index (class Index)
import Data.List (List)
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe)
import Data.Newtype (class Newtype, over, unwrap)
import Data.Set (Set)
import Data.Set as Set
import Data.Traversable (class Traversable, sequenceDefault, traverse)
import Data.Tuple (Tuple(..), fst, snd, uncurry)
import Data.Unfoldable (class Unfoldable)

newtype Graph k v
  = Graph (Map.Map k (Tuple v (Set.Set k)))

derive instance newtypeGraph :: Newtype (Graph k v) _

derive instance eqGraph :: (Eq k, Eq v) => Eq (Graph k v)

derive instance ordGraph :: (Ord k, Ord v) => Ord (Graph k v)

derive newtype instance showGraph :: (Show k, Show v) => Show (Graph k v)

derive newtype instance encodeJsonGraph :: (Ord k, EncodeJson k, EncodeJson v) => EncodeJson (Graph k v)

derive newtype instance decodeJsonGraph :: (Ord k, DecodeJson k, DecodeJson v) => DecodeJson (Graph k v)

instance functorGraph :: Ord k => Functor (Graph k) where
  map f (Graph m) = Graph (map (lmap f) m)

instance semigroupGraph :: (Ord k, Semigroup v) => Semigroup (Graph k v) where
  append (Graph m) (Graph m') = Graph $ Map.unionWith f m m'
    where
    f (Tuple v k) (Tuple v' k') = Tuple (v <> v') $ k `Set.union` k'

instance monoidGraph :: (Ord k, Semigroup v) => Monoid (Graph k v) where
  mempty = emptyGraph

instance foldableGraph :: Ord k => Foldable (Graph k) where
  foldMap f = foldMap (f <<< fst) <<< unwrap
  foldr f = foldrDefault f
  foldl f = foldlDefault f

instance traversableGraph :: Ord k => Traversable (Graph k) where
  traverse f (Graph m) = Graph <$> traverse (uncurry f') m
    where
    f' v k = (flip Tuple $ k) <$> f v
  sequence = sequenceDefault

instance indexGraph :: Ord k => Index (Graph k v) k v where
  -- no idea what this does... 
  -- copied from the source of the profunctor-lesnes library
  -- modified just a tiny bit to work with graphs
  ix k =
    wander \coalg m ->
      lookup k m
        # maybe
            (pure m)
            (coalg >>> map \v -> insert k v m)

instance atGraph :: Ord k => At (Graph k v) k v where
  -- good thing at least I understand this one:)
  at k = lens (lookup k) \m -> maybe (delete k m) (\v -> insert k v m)

-- Filer vertices based on a predicate
filterVertices :: forall k v. Ord k => (v -> Boolean) -> Graph k v -> Graph k v
filterVertices filterFunction = Graph <<< filter (filterFunction <<< fst) <<< unwrap

-- A graph with nothing in it
emptyGraph :: forall k v. Ord k => Graph k v
emptyGraph = Graph $ Map.empty

toMap :: forall k v. Ord k => Graph k v -> Map.Map k v
toMap = map fst <<< unwrap

singleton :: forall k v. Ord k => k -> v -> Graph k v
singleton k v = Graph $ Map.singleton k $ Tuple v Set.empty

insert :: forall k v. Ord k => k -> v -> Graph k v -> Graph k v
insert key value (Graph m) = Graph $ Map.alter (Just <<< (maybe (Tuple value Set.empty) $ lmap $ const value)) key m

lookup :: forall k v. Ord k => k -> Graph k v -> Maybe v
lookup k = map fst <<< Map.lookup k <<< unwrap

delete :: forall k v. Ord k => k -> Graph k v -> Graph k v
delete key = parents' <<< (over Graph $ Map.delete key)
  where
  parents' :: Graph k v -> Graph k v
  parents' graph = foldr (flip removeEdge key) graph $ parents key graph

keys :: forall k v. Ord k => Graph k v -> Set k
keys = Map.keys <<< unwrap

vertices :: forall k v. Ord k => Graph k v -> List v
vertices = map fst <<< Map.values <<< unwrap

toUnfoldable :: forall u k v. Unfoldable u => Ord k => Graph k v -> u (Tuple k v)
toUnfoldable (Graph m) = Map.toUnfoldable $ fst <$> m

--  Insert an edge from the start key to the end key.
insertEdge :: forall k v. Ord k => k -> k -> Graph k v -> Graph k v
insertEdge from to (Graph g) = Graph $ Map.alter (map $ rmap $ Set.insert to) from g

-- same as insertEdge but removes the edge instead
removeEdge :: forall k v. Ord k => k -> k -> Graph k v -> Graph k v
removeEdge from to (Graph g) = Graph $ Map.alter (map $ rmap $ Set.delete to) from g

-- Get all the edges from a graph
edges :: forall k v u. Unfoldable u => Ord k => Graph k v -> u (Tuple k k)
edges (Graph map) = Array.toUnfoldable edgeArray
  where
  edgeArray =
    Map.toUnfoldable map
      >>= (\(Tuple from (Tuple _ to)) -> Tuple from <$> Set.toUnfoldable to)

-- Get all children of a key
children :: forall k v. Ord k => k -> Graph k v -> Set k
children k (Graph g) = maybe mempty (Set.fromFoldable <<< snd) <<< Map.lookup k $ g

-- Checks if given key is part of a cycle.
isInCycle :: forall k v. Ord k => k -> Graph k v -> Boolean
isInCycle k' g = go mempty k'
  where
  go seen k = case Tuple (dd == mempty) (k `Set.member` seen) of
    Tuple true _ -> false
    Tuple _ true -> k == k'
    Tuple false false -> Foldable.any (go (Set.insert k seen)) dd
    where
    dd = children k g

-- | Same as isInCycle but doesn't return true for nodes referencing themselves
isInOutsideCycle :: forall k v. Ord k => k -> Graph k v -> Boolean
isInOutsideCycle k' g = go mempty k'
  where
  go seen k = case Tuple (dd == mempty) (k `Set.member` seen) of
    Tuple true _ -> false
    Tuple _ true -> k == k'
    Tuple false false -> Foldable.any (go (Set.insert k seen)) dd
    where
    dd = children k g `Set.difference` Set.singleton k

-- Checks if there any cycles in graph.
isCyclic :: forall k v. Ord k => Graph k v -> Boolean
isCyclic g = Foldable.any (flip isInCycle g) <<< keys $ g

-- Checks if there are any cycles with at least 2 nodes in it 
hasBigCycle :: forall k v. Ord k => Graph k v -> Boolean
hasBigCycle g = Foldable.any (flip isInOutsideCycle g) <<< keys $ g

-- no idea how to implement this so I'm using an implementation from another lib
topologicalSort :: forall k v. Ord k => Graph k v -> List k
topologicalSort = CG.topologicalSort <<< CG.fromMap <<< unwrap

-- | Returns immediate ancestors of given key.
parents :: forall k v. Ord k => k -> Graph k v -> Set k
parents k (Graph graph) = Map.keys <<< Map.filter (Foldable.elem k <<< snd) $ graph

-- Check if adding an edge would create a cycle
wouldCreateCycle :: forall k v. Ord k => k -> k -> Graph k v -> Boolean
wouldCreateCycle from to = isCyclic <<< insertEdge from to

-- Check if adding an edge would create a long cycle
wouldCreateLongCycle :: forall k v. Ord k => k -> k -> Graph k v -> Boolean
wouldCreateLongCycle from to = hasBigCycle <<< insertEdge from to

-- Count the number of vertices in a graph
size :: forall k v. Ord k => Graph k v -> Int
size = Map.size <<< unwrap

-- Reverse all the edges in the graph
-- TODO: make this only iterate trough the edgeList once.
-- Curently this is O(N ^ 2) but in theory it could be O(N)
invert :: forall k v. Ord k => Graph k v -> Graph k v
invert graph@(Graph map) = Graph $ Map.mapMaybeWithKey go map
  where
  -- We need the type definition so purescript knows what Unfoldable instance to use
  edgeList :: Array _
  edgeList = edges graph

  go key (Tuple value _) =
    Just
      $ Tuple value
      $ Set.fromFoldable
      $ filterMap (uncurry $ flip $ voidLeft <<< guard <<< eq key) edgeList
