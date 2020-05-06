module Lunarbox.Control.Monad.Dataflow.Solve.Unify
  ( unify
  , unifyMany
  , canUnify
  ) where

import Prelude
import Data.Either (isRight)
import Data.List (List(..), (:))
import Data.Map as Map
import Data.Set as Set
import Lunarbox.Control.Monad.Dataflow.Solve (Solve, SolveContext(..), runSolve, throwTypeError)
import Lunarbox.Data.Dataflow.Class.Substituable (class Substituable, Substitution(..), apply, ftv)
import Lunarbox.Data.Dataflow.Type (TVarName, Type(..))
import Lunarbox.Data.Dataflow.TypeError (TypeError(..))

-- check if a type is recursive
isRecursive :: forall a. Substituable a => TVarName -> a -> Boolean
isRecursive subst t = subst `Set.member` ftv t

-- Bind a variable to something else in a substitution
bindVariable :: forall l. TVarName -> Type -> Solve l Substitution
bindVariable a t
  | t == TVariable false a || t == TVariable true a = pure mempty
  | isRecursive a t = throwTypeError $ RecursiveType a t
  | otherwise = pure $ Substitution $ Map.singleton a t

unify :: forall l. Type -> Type -> Solve l Substitution
unify t t'
  | t == t' = pure mempty

unify t@(TVariable false _) (TVariable true v) = bindVariable v t

unify (TVariable true v) t@(TVariable false _) = bindVariable v t

unify t (TVariable false v) = bindVariable v t

unify (TVariable _ v) t = bindVariable v t

unify t (TVariable _ v) = bindVariable v t

unify (TArrow f t) (TArrow f' t') = unifyMany (f : t : Nil) (f' : t' : Nil)

unify t1 t2 = throwTypeError $ TypeMissmatch t1 t2

unifyMany :: forall l. List Type -> List Type -> Solve l Substitution
unifyMany Nil Nil = pure mempty

unifyMany (t : ts) (t' : ts') = do
  substitution <- unify t t'
  substitution' <- unifyMany (apply substitution $ ts) (apply substitution $ ts')
  pure (substitution' <> substitution)

unifyMany types types' = throwTypeError $ DifferentLength types types'

-- Check if it's possible to unify 2 types without erroring out
canUnify :: Type -> Type -> Boolean
canUnify type' = isRight <<< runSolve (SolveContext { location: unit }) <<< unify type'
