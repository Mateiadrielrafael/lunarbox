module Lunarbox.Control.Monad.Dataflow.Infer.InferExpression
  ( infer, instantiate
  ) where

import Prelude
import Control.Monad.Reader (ask, asks, local)
import Control.Monad.State (gets, modify_)
import Control.Monad.Writer (listen)
import Data.Array (zip)
import Data.Lens (over, view)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Set as Set
import Data.Traversable (for_, sequence)
import Data.Tuple (Tuple(..))
import Lunarbox.Control.Monad.Dataflow.Infer (Infer, InferOutput(..), _count, _typeEnv, createConstraint, createError, rememberType, withLocation)
import Lunarbox.Control.Monad.Dataflow.Solve (SolveContext(..), SolveState(..), runSolve)
import Lunarbox.Control.Monad.Dataflow.Solve.SolveConstraintSet (solve)
import Lunarbox.Data.Dataflow.Class.Substituable (Substitution(..), apply, ftv)
import Lunarbox.Data.Dataflow.Expression (Expression(..), NativeExpression(..), VarName, getLocation)
import Lunarbox.Data.Dataflow.Scheme (Scheme(..))
import Lunarbox.Data.Dataflow.Type (TVarName(..), Type(..), typeBool, typeFunction)
import Lunarbox.Data.Dataflow.TypeEnv (TypeEnv(..))
import Lunarbox.Data.Dataflow.TypeEnv as TypeEnv
import Lunarbox.Data.Dataflow.TypeError (TypeError(..))

-- Create a fewsh type variable
-- Uses the state from within the Infer monad to prevent duplicates
fresh :: forall l. Ord l => Show l => Boolean -> Infer l Type
fresh generalizable = do
  count <- gets $ view _count
  modify_
    $ over _count (_ + 1)
  pure
    $ TVariable generalizable
    $ TVarName
    $ "t"
    <> show count

-- Create a scope for a variable to be in
createClosure :: forall l a. Ord l => VarName -> Scheme -> Infer l a -> Infer l a
createClosure name scheme =
  let
    scope (TypeEnv env) = cleaned <> TypeEnv.singleton name scheme
      where
      cleaned = TypeEnv $ (Map.delete name) env
  in
    local $ over _typeEnv scope

-- The opposite of generalie. Takes a Forall type and creates a type out of it it
instantiate :: forall l. Ord l => Show l => Scheme -> Infer l Type
instantiate (Forall q t) = do
  q' <- sequence $ fresh true <$ q
  let
    scheme = Substitution $ Map.fromFoldable $ zip q q'
  pure $ apply scheme t

-- The opposite of instantiate. Takes a type, finds all the unresolved variables and packs them in a Forall instance. 
generalize :: forall l. Ord l => Type -> Infer l Scheme
generalize t = do
  env <- asks $ view _typeEnv
  let
    qunatifiers = ftv t `Set.difference` ftv env # Set.toUnfoldable
  pure $ Forall qunatifiers t

-- Lookup a TypeEnv and return the type. If the type doen't exist an error is thrown 
lookupEnv :: forall l. Ord l => Show l => VarName -> Infer l Type
lookupEnv var = do
  (TypeEnv env) <- asks $ view _typeEnv
  case Map.lookup var env of
    Nothing -> do
      createError $ UnboundVariable var
      fresh false
    Just s -> instantiate s

-- Infers a type and marks it location on the typeMap
infer :: forall l. Ord l => Show l => Expression l -> Infer l Type
infer expression =
  withLocation (getLocation expression) do
    type' <- case expression of
      Variable _ name -> do
        lookupEnv name
      Lambda _ param body -> do
        tv <- fresh true
        t <- createClosure param (Forall [] tv) $ infer body
        pure $ typeFunction tv t
      FunctionCall _ func input -> do
        funcType <- infer func
        inputType <- infer input
        tv <- fresh true
        createConstraint funcType (typeFunction inputType tv)
        pure tv
      If _ cond then' else' -> do
        tyCond <- infer cond
        tyThen <- infer then'
        tyElse <- infer else'
        tv <- fresh true
        createConstraint tyCond typeBool
        createConstraint tv tyThen
        createConstraint tv tyElse
        pure tv
      Let location name value body -> do
        env <- ask
        Tuple valueType (InferOutput { constraints }) <- listen $ infer value
        let
          (Tuple subst (SolveState { errors })) = runSolve (SolveContext { location }) $ solve constraints
        for_ errors $ createError <<< Stacked
        generalized <- local (const $ apply subst env) $ generalize $ apply subst valueType
        createClosure name generalized $ infer body
      FixPoint loc name body -> do
        tv <- fresh true
        ty <- createClosure name (Forall [] tv) $ infer body
        createConstraint tv ty
        pure ty
      Expression _ inner -> infer inner
      TypedHole _ -> fresh false
      Native _ (NativeExpression scheme _) -> instantiate scheme
    rememberType type'
