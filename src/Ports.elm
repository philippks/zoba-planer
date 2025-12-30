port module Ports exposing
    ( setCachedCoordinates
    , initMap
    , clearMap
    , initRenderRouteMaps
    , addMarkers
    , markerClicked
    )

import Delivery exposing (Coordinates)


-- OUTGOING PORTS


port setCachedCoordinates : List ( String, ( String, Coordinates ) ) -> Cmd msg


port initMap : Coordinates -> Cmd msg


port clearMap : () -> Cmd msg


port initRenderRouteMaps : ( Coordinates, CoordinatesByClusterAndSlot ) -> Cmd msg


port addMarkers : ( String, Coordinates, List ( Int, Coordinates, Int ) ) -> Cmd msg



-- INCOMING PORTS


port markerClicked : (Int -> msg) -> Sub msg



-- TYPES


type alias CoordinatesByClusterAndSlot =
    List ( String, List ( Int, List ( Int, Coordinates ) ) )
