module Lunarbox.Component.Modal
  ( Query(..)
  , Action(..)
  , Output(..)
  , Input
  , ButtonConfig
  , InputType
  , component
  ) where

import Prelude
import Control.Monad.State (get, gets)
import Control.MonadZero (guard)
import Control.Promise (Promise, toAff)
import Data.Lens (Lens')
import Data.Lens.Record (prop)
import Data.Maybe (Maybe(..))
import Data.Symbol (SProxy(..))
import Effect (Effect)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (class MonadEffect, liftEffect)
import Halogen (AttrName(..), ClassName(..), Component, ComponentSlot, HalogenM, defaultEval, fork, mkComponent, mkEval, raise)
import Halogen.HTML as HH
import Halogen.HTML.Events (onClick)
import Halogen.HTML.Properties as HP
import Halogen.HTML.Properties.ARIA as AP
import Lunarbox.Component.Utils (className)
import Web.HTML (HTMLElement)

foreign import showModal :: String -> Effect (Promise HTMLElement)

foreign import closeModal :: String -> Effect Unit

data Action a v
  = CloseModal v
  | Bubble a

data Query a
  = Close a
  | Open a

type ButtonConfig v
  = { text :: String
    -- TODO: make this more generic once I make a separate button component or something
    , primary :: Boolean
    , value :: v
    }

type Input h a v pa r
  = ( id :: String
    , title :: String
    , content :: (pa -> a) -> HH.HTML h a
    , buttons :: Array (ButtonConfig v)
    , onClose :: v
    | r
    )

type State h a v pa
  = Input h a v pa ()

_open :: forall r. Lens' { open :: Boolean | r } Boolean
_open = prop (SProxy :: SProxy "open")

type ChildSlots
  = ()

type InputType v pa m
  = { 
    | Input (ComponentSlot HH.HTML () m (Action pa v))
      (Action pa v)
      v
      pa
      ()
    }

data Output pa v
  = ClosedWith v
  | BubbledAction pa

component ::
  forall m v pa.
  MonadEffect m =>
  MonadAff m => Component HH.HTML Query (InputType v pa m) (Output pa v) m
component =
  mkComponent
    { initialState: identity
    , render
    , eval:
      mkEval
        $ defaultEval
            { handleAction = handleAction
            , handleQuery = handleQuery
            }
    }
  where
  handleAction ::
    Action pa v ->
    HalogenM { | State _ _ v pa } (Action pa v) ChildSlots
      (Output pa v)
      m
      Unit
  handleAction = case _ of
    CloseModal value -> do
      id <- gets _.id
      liftEffect $ closeModal id
      raise $ ClosedWith value
    Bubble a -> raise $ BubbledAction a

  handleQuery ::
    forall a.
    Query a ->
    HalogenM { | State _ _ v pa }
      (Action pa v)
      ChildSlots
      (Output pa v)
      m
      (Maybe a)
  handleQuery = case _ of
    Open return -> do
      { id, onClose } <- get
      void
        $ fork do
            void $ liftAff $ map toAff $ liftEffect $ showModal id
            raise $ ClosedWith onClose
      pure $ Just return
    Close a -> do
      id <- gets _.id
      liftEffect $ closeModal id
      pure $ Just a

  render { id, title, content, buttons } =
    HH.div
      [ HP.id_ id
      , AP.hidden "true"
      , className "modal micromodal-slide"
      ]
      [ HH.div
          [ HP.tabIndex (-1)
          , HP.attr (AttrName "data-micromodal-close") "true"
          , className "modal__overlay"
          ]
          [ HH.div
              [ AP.role "dialog"
              , HP.attr (AttrName "aria-modal") "true"
              , AP.labelledBy titleId
              , className "modal__container"
              ]
              [ HH.header [ className "modal__header" ]
                  [ HH.h2 [ HP.id_ titleId, className "modal__title" ]
                      [ HH.text title
                      ]
                  ]
              , HH.main [ HP.id_ contentId, className "modal__content" ]
                  [ content Bubble
                  ]
              , HH.footer [ className "modal__footer" ]
                  $ ( \{ text, primary, value } ->
                        HH.button
                          [ HP.classes
                              $ ClassName
                              <$> ("modal__btn-primary" <$ guard primary)
                              <> [ "modal__btn" ]
                          , onClick $ const $ Just $ CloseModal value
                          ]
                          [ HH.text text ]
                    )
                  <$> buttons
              ]
          ]
      ]
    where
    titleId = id <> "-title"

    contentId = id <> "-content"
