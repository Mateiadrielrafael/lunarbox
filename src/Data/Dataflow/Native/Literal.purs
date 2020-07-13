module Lunarbox.Data.Dataflow.Native.Literal
  ( literalNodes
  ) where

import Prelude
import Lunarbox.Data.Dataflow.Expression (NativeExpression(..))
import Lunarbox.Data.Dataflow.Native.NativeConfig (NativeConfig(..))
import Lunarbox.Data.Dataflow.Runtime (RuntimeValue(..))
import Lunarbox.Data.Dataflow.Scheme (Scheme(..))
import Lunarbox.Data.Dataflow.Type (typeBool, typeNumber, typeString)
import Lunarbox.Data.Editor.FunctionData (internal)
import Lunarbox.Data.Editor.FunctionName (FunctionName(..))

-- All the native literal nodes
literalNodes :: Array (NativeConfig)
literalNodes = [ boolean, number, string ]

-- booleaUi ::
--    FunctionUi a s m
-- booleaUi { value } { setValue } =
--   SE.foreignObject
--     [ SA.height switchHeight
--     , SA.width switchWidth
--     , SA.x $ switchWidth / -2.0
--     ]
--     [ switch { checked: toBoolean value, round: true } (setValue <<< Bool)
--     ]
boolean :: NativeConfig
boolean =
  NativeConfig
    { name: FunctionName "boolean"
    , expression: (NativeExpression (Forall [] typeBool) $ Bool false)
    , functionData: internal [] { name: "Boolean", description: "A boolean which has the same value as the visual switch" }
    }

-- numberUi ::  FunctionUi a s m
-- numberUi { value } { setValue } =
--   SE.foreignObject
--     [ SA.height switchHeight
--     , SA.width inputWIdth
--     , SA.x $ inputWIdth / -2.0
--     ]
--     [ HH.input
--         [ HP.value $ show $ toNumber value
--         , HP.type_ HP.InputNumber
--         , className "number node-input"
--         , onValueInput $ setValue <=< map Number <<< fromString
--         ]
--     ]
number :: NativeConfig
number =
  NativeConfig
    { name: FunctionName "number"
    , expression: (NativeExpression (Forall [] typeNumber) $ Number 0.0)
    , functionData: internal [] { name: "Number", description: "A number which has the same value as the input box" }
    }

-- stringUI ::  FunctionUi a s m
-- stringUI { value } { setValue } =
--   SE.foreignObject
--     [ SA.height switchHeight
--     , SA.width inputWIdth
--     , SA.x $ inputWIdth / -2.0
--     ]
--     [ HH.input
--         [ HP.value $ toString value
--         , HP.type_ HP.InputText
--         , className "string node-input"
--         , onValueInput $ setValue <<< String
--         ]
--     ]
string :: NativeConfig
string =
  NativeConfig
    { name: FunctionName "string"
    , expression: (NativeExpression (Forall [] typeString) $ String "lunarbox")
    , functionData: internal [] { name: "String", description: "A string which has the same value as the input textbox" }
    }
