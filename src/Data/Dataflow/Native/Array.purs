module Lunarbox.Data.Dataflow.Native.Array (arrayNodes) where

import Prelude
import Data.Array (cons, snoc)
import Data.Array as Array
import Data.Filterable (filter)
import Data.Int (floor)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Symbol (SProxy(..))
import Data.Tuple (Tuple(..))
import Lunarbox.Data.Dataflow.Expression (NativeExpression(..))
import Lunarbox.Data.Dataflow.Native.NativeConfig (NativeConfig(..))
import Lunarbox.Data.Dataflow.Runtime (RuntimeValue(..), binaryFunction, ternaryFunction, toArray, toBoolean)
import Lunarbox.Data.Dataflow.Runtime.Class.Describable (DProxy(..), toNativeExpression)
import Lunarbox.Data.Dataflow.Scheme (Scheme(..))
import Lunarbox.Data.Dataflow.Type (createTypeVariable, multiArgumentFuncion, typeArray, typeBool, typeFunction, typeNumber)
import Lunarbox.Data.Editor.FunctionData (internal)
import Lunarbox.Data.Editor.FunctionName (FunctionName(..))
import Math as Number

-- List will all the native array nodes
arrayNodes :: Array (NativeConfig)
arrayNodes = [ emptyArray, cons', snoc', map', filter', flatMap, wrap', flat, match, concatArrays, lookup ]

-- A constant equal to an array with 0 elements
typeEmptyArray :: Scheme
typeEmptyArray = Forall [ a ] $ typeArray typeA
  where
  Tuple a typeA = createTypeVariable "t0"

emptyArray :: NativeConfig
emptyArray =
  NativeConfig
    { name: FunctionName "empty array"
    , expression: (NativeExpression typeEmptyArray $ NArray [])
    , functionData: internal [] { name: "array", description: "An array containing no elements" }
    }

-- Given a and [a] returns an array having a as the first element and everything else afte that
cons' :: NativeConfig
cons' =
  NativeConfig
    { name: FunctionName "cons"
    , expression: toNativeExpression proxy
    , functionData:
        internal
          [ { name: "element", description: "A single element to add at the beginning of an array" }
          , { name: "array", description: "An array to add the given element at the start of" }
          ]
          { name: "array", description: "The resulting array which has the first argument as the first element and everything else after that" }
    }
  where
  proxy :: DProxy (SProxy "a" -> Array (SProxy "a") -> Array (SProxy "a")) _
  proxy = DProxy eval

  eval :: RuntimeValue -> Array RuntimeValue -> Array RuntimeValue
  eval = cons

-- Given [a] and a returns an array having a as the last element and everything else before that
snoc' :: NativeConfig
snoc' =
  NativeConfig
    { name: FunctionName "snoc"
    , expression: toNativeExpression proxy
    , functionData:
        internal
          [ { name: "array", description: "An array to add the given element at the end of" }
          , { name: "element", description: "A single element to add at the end of an array" }
          ]
          { name: "array", description: "The resulting array which has the second argument as the last element and everything else before that" }
    }
  where
  proxy :: DProxy (Array (SProxy "a") -> SProxy "a" -> Array (SProxy "a")) _
  proxy = DProxy eval

  eval :: Array RuntimeValue -> RuntimeValue -> Array RuntimeValue
  eval = snoc

-- Mapping over arrays
typeMap :: Scheme
typeMap = Forall [ a, b ] $ typeFunction (typeFunction typeA typeB) $ typeFunction (typeArray typeA) $ typeArray typeB
  where
  Tuple a typeA = createTypeVariable "t0"

  Tuple b typeB = createTypeVariable "t1"

evalMap :: RuntimeValue -> RuntimeValue -> RuntimeValue
evalMap (Function mapper) (NArray array) = NArray $ mapper <$> array

evalMap _ _ = Null

map' :: NativeConfig
map' =
  NativeConfig
    { name: FunctionName "map array"
    , expression: (NativeExpression typeMap $ binaryFunction evalMap)
    , functionData:
        internal
          [ { name: "mapper", description: "A function to run on each element of an array" }
          , { name: "array", description: "An array to run a function on each element of"
            }
          ]
          { name: "array", description: "The result of running the given function on each element of the given array" }
    }

-- Filtering arrays
typeFilter :: Scheme
typeFilter = Forall [ a ] $ typeFunction (typeFunction typeA typeBool) $ typeFunction (typeArray typeA) $ typeArray typeA
  where
  Tuple a typeA = createTypeVariable "t0"

evalFilter :: RuntimeValue -> RuntimeValue -> RuntimeValue
evalFilter (Function function) (NArray array) = NArray $ filter (toBoolean <<< function) array

evalFilter _ _ = Null

filter' :: NativeConfig
filter' =
  NativeConfig
    { name: FunctionName "filter array"
    , expression: (NativeExpression typeFilter $ binaryFunction evalFilter)
    , functionData:
        internal
          [ { name: "function", description: "A function to decide if an element should be kept in the array or not" }
          , { name: "array", description: "The array to filter with the given function"
            }
          ]
          { name: "filtered array", description: "An array which only contains the items the given function returned true for" }
    }

-- Binding arrays basically
typeFlatMap :: Scheme
typeFlatMap = Forall [ a, b ] $ typeFunction (typeFunction typeA $ typeArray typeB) $ typeFunction (typeArray typeA) $ typeArray typeB
  where
  Tuple a typeA = createTypeVariable "t0"

  Tuple b typeB = createTypeVariable "t1"

evalFlatMap :: RuntimeValue -> RuntimeValue -> RuntimeValue
evalFlatMap (Function function) (NArray array) = NArray $ array >>= (toArray <<< function)

evalFlatMap _ _ = Null

flatMap :: NativeConfig
flatMap =
  NativeConfig
    { name: FunctionName "flatMap"
    , expression: (NativeExpression typeFlatMap $ binaryFunction evalFlatMap)
    , functionData:
        internal
          [ { name: "function", description: "A function which takes each element of an array and returns another array" }
          , { name: "array", description: "The array to pass each element of to the given function"
            }
          ]
          { name: "resulting array", description: "An array which contains the concatenated results of passing every element of the original array to the given function" }
    }

-- Wrap an value in an array with one element
typeWrap :: Scheme
typeWrap = Forall [ a ] $ typeFunction typeA $ typeArray typeA
  where
  Tuple a typeA = createTypeVariable "t0"

wrap' :: NativeConfig
wrap' =
  NativeConfig
    { name: FunctionName "wrap in array"
    , expression: (NativeExpression typeWrap $ Function $ NArray <<< pure)
    , functionData:
        internal
          [ { name: "element", description: "A value to wrap in an array"
            }
          ]
          { name: "array", description: "An array containing the input" }
    }

-- Flatten a nested array
typeFlat :: Scheme
typeFlat = Forall [ a ] $ typeFunction (typeArray $ typeArray typeA) $ typeArray typeA
  where
  Tuple a typeA = createTypeVariable "t0"

evalFlat :: RuntimeValue -> RuntimeValue
evalFlat = evalFlatMap $ Function identity

flat :: NativeConfig
flat =
  NativeConfig
    { name: FunctionName "flatten array"
    , expression: (NativeExpression typeFlat $ Function evalFlat)
    , functionData:
        internal
          [ { name: "nested array", description: "An array of arrays"
            }
          ]
          { name: "array", description: "An array containing all the elements of the nested arrays of the input." }
    }

-- Basically used to pattern match an array
typeMatch :: Scheme
typeMatch =
  Forall [ a, b ]
    $ multiArgumentFuncion
        [ typeB
        , multiArgumentFuncion
            [ typeA
            , typeArray typeA
            ]
            typeB
        , typeArray typeA
        ]
        typeB
  where
  Tuple a typeA = createTypeVariable "t0"

  Tuple b typeB = createTypeVariable "t1"

evalMatch :: RuntimeValue -> RuntimeValue -> RuntimeValue -> RuntimeValue
evalMatch default (Function function) (NArray array) = case Array.uncons array of
  Just { head, tail } -> case function head of
    Function function' -> function' $ NArray tail
    _ -> Null
  Nothing -> default

evalMatch _ _ _ = Null

match :: NativeConfig
match =
  NativeConfig
    { name: FunctionName "pattern match array"
    , expression: (NativeExpression typeMatch $ Function $ binaryFunction <<< evalMatch)
    , functionData:
        internal
          [ { name: "default value"
            , description: "If the 3rd argument is an empty array this will become the result"
            }
          , { name: "function"
            , description: "A function which takes the first element of an array as the first argument and the rest of the array as the second"
            }
          , { name: "array"
            , description: "Array to pattern match. If this is empty the defuault value will be returned. Else the head and the tail of this array will be based to the given function"
            }
          ]
          { name: "array"
          , description: "If the given array was empty this will equal the default value, else this will be the result of passing the head and the tail of the given array to the given function"
          }
    }

-- Concat 2 arrays into 1
evalConcat :: RuntimeValue -> RuntimeValue -> RuntimeValue
evalConcat (NArray first) (NArray second) = NArray $ first <> second

evalConcat _ _ = Null

typeConcat :: Scheme
typeConcat =
  Forall [ a ]
    $ multiArgumentFuncion
        [ typeArray typeA
        , typeArray typeA
        ]
    $ typeArray typeA
  where
  Tuple a typeA = createTypeVariable "t0"

concatArrays :: NativeConfig
concatArrays =
  NativeConfig
    { name: FunctionName "concat arrays"
    , expression: NativeExpression typeConcat $ binaryFunction evalConcat
    , functionData:
        internal
          [ { name: "first array", description: "Any array" }
          , { name: "second array", description: "Any array" }
          ]
          { name: "a ++ b", description: "An arrray containing the elements of both inputs" }
    }

-- Lookup an index of an array with e falback value
evalLookup :: RuntimeValue -> RuntimeValue -> RuntimeValue -> RuntimeValue
evalLookup (NArray array) (Number index) default =
  if index == Number.floor index then
    fromMaybe default $ array `Array.index` (floor index)
  else
    default

evalLookup _ _ _ = Null

typeLookup :: Scheme
typeLookup =
  Forall [ a ]
    $ multiArgumentFuncion
        [ typeArray typeA
        , typeNumber
        , typeA
        ]
        typeA
  where
  Tuple a typeA = createTypeVariable "t0"

lookup :: NativeConfig
lookup =
  NativeConfig
    { name: FunctionName "array lookup"
    , expression: NativeExpression typeLookup $ ternaryFunction evalLookup
    , functionData:
        internal
          [ { name: "array", description: "An array to lookup any index of." }
          , { name: "index", description: "An index to get from an array."
            }
          , { name: "default value", description: "A value to return in case the index isn't an integer or the index is out of bounds." }
          ]
          { name: "value at index", description: "The value at the fiven index in the array or the default value if the index is not an int or is out of bounds." }
    }
