module Lunarbox.Component.Editor.Node
  ( node
  ) where

import Prelude
import Data.Array (toUnfoldable) as Array
import Data.List (List(..))
import Data.List as List
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Typelevel.Num (d0, d1)
import Data.Vec ((!!))
import Halogen.HTML (HTML)
import Halogen.HTML as HH
import Halogen.HTML.Events (onMouseDown)
import Lunarbox.Capability.Editor.Node.NodeInput (Arc(..), fillWith)
import Lunarbox.Component.Editor.Node.Input (input)
import Lunarbox.Component.Editor.Node.Label (label)
import Lunarbox.Component.Editor.Node.Overlays (overlays)
import Lunarbox.Data.Editor.Constants (arcSpacing, arcWidth, nodeRadius)
import Lunarbox.Data.Editor.FunctionData (FunctionData(..))
import Lunarbox.Data.Editor.Node (Node)
import Lunarbox.Data.Editor.Node.NodeData (NodeData(..))
import Lunarbox.Data.Editor.Node.PinLocation (Pin(..))
import Lunarbox.Svg.Attributes (Linecap(..), strokeDashArray, strokeLinecap, strokeWidth, transparent)
import Math (pi)
import Svg.Attributes as SA
import Svg.Elements as SE

type Input
  = { nodeData :: NodeData
    , node :: Node
    , labels :: Array String
    , functionData :: FunctionData
    , colorMap :: Map Pin SA.Color
    , hasOutput :: Boolean
    }

type Actions a
  = { select :: Maybe a
    }

output :: forall r a. Boolean -> HTML r a
output false = HH.text ""

output true =
  SE.circle
    [ SA.r 10.0
    , SA.fill $ Just $ SA.RGB 118 255 0
    ]

constant :: forall r a. HTML r a
constant =
  SE.circle
    [ SA.r nodeRadius
    , SA.fill $ Just transparent
    , SA.stroke $ Just $ SA.RGB 176 112 107
    , strokeWidth arcWidth
    , strokeLinecap Butt
    , strokeDashArray [ pi * nodeRadius / 20.0 ]
    ]

node :: forall h a. Input -> Actions a -> HTML h a
node { nodeData: NodeData { position }
, functionData: FunctionData { inputs }
, labels
, colorMap
, hasOutput
} { select } =
  SE.g
    [ SA.transform [ SA.Translate (position !! d0) (position !! d1) ]
    , onMouseDown $ const select
    ]
    [ overlays $ label <$> labels
    , output hasOutput
    , let
        inputNames = Array.toUnfoldable $ _.name <$> inputs

        inputArcs = fillWith inputNames Nil
      in
        if List.null inputArcs then
          constant
        else
          SE.g
            [ SA.transform [ SA.Rotate 90.0 0.0 0.0 ]
            ]
            $ ( \arc@(Arc _ _ name) ->
                  input
                    { arc
                    , spacing: if List.length inputArcs == 1 then 0.0 else arcSpacing
                    , radius: nodeRadius
                    , color:
                      fromMaybe transparent do
                        index <- List.findIndex (name == _) inputNames
                        Map.lookup (InputPin index) colorMap
                    }
              )
            <$> List.toUnfoldable inputArcs
    ]
