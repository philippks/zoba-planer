module Shared exposing
    ( Flags, decoder
    , Model, Msg
    , init, update, subscriptions
    )

{-|

@docs Flags, decoder
@docs Model, Msg
@docs init, update, subscriptions

-}

import Delivery exposing (Coordinates)
import Dict
import Effect exposing (Effect)
import Json.Decode
import Route exposing (Route)
import Route.Path
import Shared.Model
import Shared.Msg



-- FLAGS


type alias Flags =
    { cachedCoordinates : List ( String, ( String, Coordinates ) )
    }


decoder : Json.Decode.Decoder Flags
decoder =
    Json.Decode.map Flags
        (Json.Decode.field "cachedCoordinates"
            (Json.Decode.list
                (Json.Decode.map2 Tuple.pair
                    (Json.Decode.index 0 Json.Decode.string)
                    (Json.Decode.index 1
                        (Json.Decode.map2 Tuple.pair
                            (Json.Decode.index 0 Json.Decode.string)
                            (Json.Decode.index 1
                                (Json.Decode.map2 Coordinates
                                    (Json.Decode.field "latitude" Json.Decode.float)
                                    (Json.Decode.field "longitude" Json.Decode.float)
                                )
                            )
                        )
                    )
                )
            )
        )



-- INIT


type alias Model =
    Shared.Model.Model


init : Result Json.Decode.Error Flags -> Route () -> ( Model, Effect Msg )
init flagsResult route =
    let
        cachedCoordinates =
            case flagsResult of
                Ok flags ->
                    Dict.fromList flags.cachedCoordinates

                Err _ ->
                    Dict.empty

        separator =
            ","

        input =
            """Name,Strasse,Ort,Lieferzeit
"Max Mustermann","Mythenweg 21","Hombrechtikon","08:00 - 09:00"
"Franz Müller","Baugartenstr. 13","Hombrechtikon","08:00 - 09:00"
"Heike Koller","Haldenweg 7","Hombrechtikon","08:00 - 09:00"
"Anja Kraner","Waffenplatzstr. 41","Hombrechtikon","08:00 - 09:00"
"Jimmy Meier","Etzelstr. 15","Hombrechtikon","08:00 - 09:00"
"Philipp Karrer","Glärnischstr. 20","Hombrechtikon","08:00 - 09:00"
"Monika Lausbacher","Holgassstrasse 62","Hombrechtikon","08:00 - 09:00"
"Heinrich Freier","Quellenweg 15","Hombrechtikon","08:00 - 09:00"
"Holger Bering","Breitacherstrasse 3","Hombrechtikon","08:00 - 09:00"
"Markus Günter","Bochslenstrasse 2","Hombrechtikon","09:00 - 10:00"
"Erika Andre","Eichwisstrasse 39","Hombrechtikon","09:00 - 10:00"
"Eberhardt Zirme B.A.","Bahnhofstrasse 4","Feldbach","09:00 - 10:00"
"Silva Stumpf","Hornstrasse 3","Feldbach","09:00 - 10:00"
"Prof. Walfried Hübel B.A.","Hinderschlatt 4","Hombrechtikon","09:00 - 10:00"
"Woldemar Bachmann","Blumenbergweg 5","Wolfhausen","09:00 - 10:00"
"Milena Dippel","Oetwilerstrasse 35","Hombrechtikon","09:00 - 10:00"
"Renato Kohl","Holflüestrasse 8","Hombrechtikon","09:00 - 10:00"
"Leonid Bähr","Holflüestrasse 10","Hombrechtikon","09:00 - 10:00"
"Samir Tschentscher","Bochslenstrasse 34","Hombrechtikon","09:00 - 10:00"
"Prof. Eckehard Köhler","Haldenweg 10","Hombrechtikon","10:00 - 11:00"
"Thorsten Paffrath","Tödistrasse 5","Hombrechtikon","10:00 - 11:00"
"""

        drivers =
            3

        headquarterCoordinates =
            Coordinates 47.25229 8.77175
    in
    ( { drivers = drivers
      , csvSeparator = separator
      , inputCsv = input
      , parsedCsvHeaders = []
      , deliveries = Dict.empty
      , parseCsvError = Nothing
      , cachedCoordinates = cachedCoordinates
      , headquarterCoordinates = headquarterCoordinates
      , headquarterCoordinatesString = "47.25229,8.77175"
      , headquarterCoordinatesError = Nothing
      }
    , Effect.none
    )



-- UPDATE


type alias Msg =
    Shared.Msg.Msg


update : Route () -> Msg -> Model -> ( Model, Effect Msg )
update route msg model =
    case msg of
        Shared.Msg.NoOp ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Route () -> Model -> Sub Msg
subscriptions route model =
    Sub.none
