module Lunarbox.Data.Editor.Camera
  ( Camera(..)
  , toWorldCoordinates
  , toViewBox
  , _CameraPosition
  ) where

import Prelude
import Data.Default (class Default)
import Data.Lens (Lens')
import Data.Lens.Record (prop)
import Data.Newtype (class Newtype)
import Data.Symbol (SProxy(..))
import Data.Typelevel.Num (d0, d1)
import Data.Vec ((!!))
import Halogen.HTML (IProp)
import Lunarbox.Data.Lens (newtypeIso)
import Lunarbox.Data.Vector (Vec2)
import Math (floor)
import Svg.Attributes as SA

-- Holds information about the current viewbox in an easy to store format
newtype Camera
  = Camera
  { position :: Vec2 Number
  , zoom :: Number
  }

derive instance eqCamera :: Eq Camera

derive instance newtypeCamera :: Newtype Camera _

instance defaultCamera :: Default Camera where
  def =
    Camera
      { position: zero
      , zoom: 1.0
      }

-- Project a point on the screen into world coordinates
toWorldCoordinates :: Camera -> Vec2 Number -> Vec2 Number
toWorldCoordinates (Camera { position, zoom }) vec = position + ((_ / zoom) <$> vec)

-- Generate a svg viewbox from a Camera
toViewBox :: forall r i. Vec2 Number -> Camera -> IProp ( viewBox ∷ String | r ) i
toViewBox scale (Camera { position, zoom }) =
  SA.viewBox (floor $ position !! d0)
    (floor $ position !! d1)
    (floor $ scale !! d0 * zoom)
    (floor $ scale !! d1 * zoom)

-- Lenses
_CameraPosition :: Lens' Camera (Vec2 Number)
_CameraPosition = newtypeIso <<< prop (SProxy :: _ "position")
