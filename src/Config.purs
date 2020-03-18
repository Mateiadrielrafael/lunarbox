module Lunarbox.Config (Config(..), DevOptions(..), shouldBlurInputs) where

import Prelude
import Control.Monad.Reader (class MonadAsk, asks)
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype, unwrap)

type DevOptions
  = Maybe
      -- It is usually useful to be able to not cancel  -- inputs when bluring off of them for debugging purpouses 
      { cancelInputsOnBlur :: Boolean
      }

newtype Config
  = Config
  { devOptions :: DevOptions
  }

derive instance newtypeConfig :: Newtype Config _

shouldBlurInputs :: forall m. Monad m => MonadAsk Config m => m Boolean
shouldBlurInputs = do
  { devOptions } <- asks unwrap
  case devOptions of
    Just { cancelInputsOnBlur } -> pure cancelInputsOnBlur
    Nothing -> pure true
