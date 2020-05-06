module Lunarbox.Control.Monad.Dataflow.Interpreter.Interpret
  ( interpret
  , withTerm
  ) where

import Prelude
import Control.Monad.Reader (ask, asks, local)
import Control.Monad.Writer (tell)
import Data.Default (class Default, def)
import Data.Lens (over, set, view)
import Data.List as List
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Newtype (unwrap)
import Data.Tuple (fst)
import Lunarbox.Control.Monad.Dataflow.Interpreter (Interpreter, _location, _overwrites, _termEnv, runInterpreter)
import Lunarbox.Data.Dataflow.Expression (Expression(..), NativeExpression(..), getLocation)
import Lunarbox.Data.Dataflow.Runtime (RuntimeValue(..))
import Lunarbox.Data.Dataflow.Runtime.TermEnvironment as TermEnvironment
import Lunarbox.Data.Dataflow.Runtime.ValueMap (ValueMap(..))
import Lunarbox.Data.Dataflow.Scheme (Scheme(..))
import Lunarbox.Data.Dataflow.Type (typeString)

-- Gets a value from the current environment
getVariable :: forall l. Ord l => String -> Interpreter l RuntimeValue
getVariable name = do
  env <- asks $ view _termEnv
  pure $ TermEnvironment.lookup name env

-- Perform an action in an environment with an extra variable
withTerm :: forall l. Ord l => String -> RuntimeValue -> Interpreter l ~> Interpreter l
withTerm name value = local $ over _termEnv $ TermEnvironment.insert name value

-- Wrap a runtime value in an expression
makeNative :: forall l. Ord l => Default l => RuntimeValue -> Expression l
makeNative = Native def <<< NativeExpression (Forall [] typeString)

-- Interpret an expression into a runtimeValue
interpret :: forall l. Ord l => Default l => Expression l -> Interpreter l RuntimeValue
interpret expression = do
  overwrites <- asks $ view _overwrites
  let
    location = getLocation expression

    maybeOverwrite = Map.lookup location $ unwrap overwrites
  value <- case maybeOverwrite of
    Just overwrite -> pure overwrite
    Nothing ->
      local (set _location location) case expression of
        TypedHole _ -> pure Null
        Variable _ name -> getVariable $ show name
        Lambda _ argumentName body -> do
          env <- ask
          -- This is here to generate data for node uis
          void $ withTerm (show argumentName) Null $ interpret body
          pure $ Function
            $ \argument ->
                fst
                  $ runInterpreter env
                  $ withTerm (show argumentName) argument
                  $ interpret body
        Chain _ expressions -> case List.last expressions of
          Just expression' -> interpret expression'
          Nothing -> pure Null
        Let _ name value body -> do
          runtimeValue <- interpret value
          withTerm (show name) runtimeValue $ interpret body
        FixPoint _ function -> do
          env <- ask
          interpret $ FunctionCall location function $ FixPoint def function
        Native _ (NativeExpression _ inner) -> pure inner
        FunctionCall _ function argument -> do
          runtimeArgument <- interpret argument
          runtimeFunction <- interpret function
          pure case runtimeFunction of
            Function call -> call runtimeArgument
            _ -> Null
  tell $ ValueMap $ Map.singleton location value
  pure value