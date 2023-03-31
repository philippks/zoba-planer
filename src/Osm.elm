module Osm exposing (OsmItem, OsmQueryResult, houseCoordinatesFromOsmResponse, osmItemDecoder, osmResponseDecoder, queryOsm)

import Http
import Json.Decode as JsonDecode
import Json.Decode.Pipeline as JsonDecodePipeline


type alias OsmQueryResult =
    Result Http.Error (List OsmItem)


type alias OsmItem =
    { osm_id : Int
    , lat : String
    , lon : String
    , class : String
    }


queryOsm : id -> String -> String -> (id -> OsmQueryResult -> msg) -> Cmd msg
queryOsm id street city msg =
    Http.get
        { url = "https://nominatim.openstreetmap.org/search?format=json&street=" ++ street ++ "&city=" ++ city
        , expect = Http.expectJson (msg id) osmResponseDecoder
        }


osmResponseDecoder : JsonDecode.Decoder (List OsmItem)
osmResponseDecoder =
    JsonDecode.list osmItemDecoder


osmItemDecoder : JsonDecode.Decoder OsmItem
osmItemDecoder =
    JsonDecode.succeed
        OsmItem
        |> JsonDecodePipeline.required "osm_id" JsonDecode.int
        |> JsonDecodePipeline.required "lat" JsonDecode.string
        |> JsonDecodePipeline.required "lon" JsonDecode.string
        |> JsonDecodePipeline.required "class" JsonDecode.string


houseCoordinatesFromOsmResponse : (String -> String -> Result String coordinates) -> OsmQueryResult -> Result String coordinates
houseCoordinatesFromOsmResponse parseCoordinates result =
    case result of
        Ok items ->
            case List.head items of
                Just item ->
                    houseCoordinatesFromOsmItem parseCoordinates item

                _ ->
                    Err "Nicht gefunden"

        Err _ ->
            Err "Fehler beim Suchen"


houseCoordinatesFromOsmItem : (String -> String -> Result String coordinates) -> OsmItem -> Result String coordinates
houseCoordinatesFromOsmItem parseCoordinates osmItem =
    case osmItem.class of
        "building" ->
            parseCoordinates osmItem.lat osmItem.lon

        "place" ->
            parseCoordinates osmItem.lat osmItem.lon

        "shop" ->
            parseCoordinates osmItem.lat osmItem.lon

        "craft" ->
            parseCoordinates osmItem.lat osmItem.lon

        "amenity" ->
            parseCoordinates osmItem.lat osmItem.lon

        other ->
            Err ("Es wurde kein Gebäude, sondern ein \"" ++ other ++ "\" gefunden")
