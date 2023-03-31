module Example exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Main exposing (Coordinates, OsmItem, coordinatesStatusFromOsmResponse, getCoordinatesFromOsmItem, parseCoordinates)
import Test exposing (..)


parseCoordinatesTest : Test
parseCoordinatesTest =
    describe "parseCoordinates"
        [ test "something" <|
            \_ ->
                parseCoordinates "41.12" "8.2"
                    |> Expect.equal (Ok (Coordinates 41.12 8.2))
        ]


getCoordinatesTest : Test
getCoordinatesTest =
    let
        osmItem =
            OsmItem 1337 "41.12" "8.2" "building"
    in
    describe
        "getCoordinates"
        [ test "returns coordinates for building" <|
            \_ ->
                osmItem
                    |> getCoordinatesFromOsmItem
                    |> Expect.equal (Ok (Coordinates 41.12 8.2))
        , test "fails if osm does not return a building" <|
            \_ ->
                { osmItem | class = "street" }
                    |> getCoordinatesFromOsmItem
                    |> Expect.equal (Err "OSM did not return a building, but a street")
        ]


osmQueryResultToFetchCoordinatesStatus : Test
osmQueryResultToFetchCoordinatesStatus =
    let
        queryResult =
            OsmQueryResult Ok
    in
    describe
        "osmQueryResultToFetchCoordinatesStatus"
        [ test "returns coordinates for building" <|
            \_ ->
                osmItem
                    |> coordinatesStatusFromOsmResponse
                    |> Expect.equal (Ok (Coordinates 41.12 8.2))
        ]
