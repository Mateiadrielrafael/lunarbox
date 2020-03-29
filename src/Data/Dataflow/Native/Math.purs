module Lunarbox.Data.Dataflow.Native.Math (add) where

import Lunarbox.Data.Dataflow.FunctionName (FunctionName(..))
import Lunarbox.Data.Dataflow.Native.NativeConfig (NativeConfig(..))
import Lunarbox.Data.Dataflow.Runtime (RuntimeValue(..), binaryFunction)
import Lunarbox.Data.FunctionData (FunctionData)
import Lunarbox.Dataflow.Expression (NativeExpression(..))
import Lunarbox.Dataflow.Type (Type(..), typeNumber)
import Prelude (mempty, ($), (+))

addT :: Type
addT = TArrow typeNumber $ TArrow typeNumber typeNumber

addRuntimeValue :: RuntimeValue -> RuntimeValue -> RuntimeValue
addRuntimeValue (Number n) (Number n') = Number $ n + n'

addRuntimeValue _ _ = Null

add :: NativeConfig FunctionData
add =
  NativeConfig
    { name: FunctionName "add"
    , expression: (NativeExpression addT $ binaryFunction addRuntimeValue)
    , functionData: mempty
    }
