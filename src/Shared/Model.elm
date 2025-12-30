module Shared.Model exposing (Model)

{-| -}

import Delivery exposing (Coordinates, CoordinatesCache, Deliveries)
import Dict


{-| Normally, this value would live in "Shared.elm"
but that would lead to a circular dependency import cycle.

For that reason, both `Shared.Model` and `Shared.Msg` are in their
own file, so they can be imported by `Effect.elm`

-}
type alias Model =
    { drivers : Int
    , csvSeparator : String
    , inputCsv : String
    , parsedCsvHeaders : List String
    , deliveries : Deliveries
    , parseCsvError : Maybe String
    , cachedCoordinates : CoordinatesCache
    , headquarterCoordinates : Coordinates
    , headquarterCoordinatesString : String
    , headquarterCoordinatesError : Maybe String
    }
