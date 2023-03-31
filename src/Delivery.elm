module Delivery exposing (..)

import Array
import Csv
import Dict exposing (Dict)
import KMeans
import Result.Extra
import Set


type alias Deliveries =
    Dict Int Delivery


type alias Delivery =
    { id : Int
    , csvRecords : Dict String String
    , coordinates : CoordinatesStatus
    , cluster : Int
    }


type CoordinatesStatus
    = NotFetched
    | Fetching
    | FetchError String
    | FetchSuccess Coordinates
    | SetManually ( String, Result String Coordinates )


type alias Coordinates =
    { latitude : Float
    , longitude : Float
    }


streetKey : String
streetKey =
    "Strasse"


cityKey : String
cityKey =
    "Ort"


slotKey : String
slotKey =
    "Lieferzeit"


setDeliveryCoordinates : Int -> CoordinatesStatus -> Deliveries -> Deliveries
setDeliveryCoordinates id coordinates deliveries =
    Dict.update id (Maybe.map (\delivery -> { delivery | coordinates = coordinates })) deliveries


deliveriesCoordinates : List Delivery -> List ( Int, Coordinates )
deliveriesCoordinates deliveries =
    List.foldl
        (\delivery acc ->
            case deliveryCoordinates delivery of
                Just coordinates ->
                    ( delivery.id, coordinates ) :: acc

                Nothing ->
                    acc
        )
        []
        deliveries


deliveryCoordinates : Delivery -> Maybe Coordinates
deliveryCoordinates delivery =
    case delivery.coordinates of
        FetchSuccess coordinates ->
            Just coordinates

        SetManually ( _, result ) ->
            case result of
                Ok coordinates ->
                    Just coordinates

                _ ->
                    Nothing

        _ ->
            Nothing


slotsOfDeliveries : Deliveries -> List String
slotsOfDeliveries deliveries =
    deliveries
        |> Dict.values
        |> List.map (getValue slotKey)
        |> Set.fromList
        |> Set.toList
        |> List.sort


clustersOfDeliveries : List Delivery -> List Int
clustersOfDeliveries deliveries =
    deliveries
        |> List.map .cluster
        |> Set.fromList
        |> Set.toList
        |> List.sort


deliveriesOfSlot : String -> Deliveries -> List Delivery
deliveriesOfSlot slot deliveries =
    deliveries |> Dict.values |> List.filter (\delivery -> getSlot delivery == slot)


deliveriesOfCluster : Int -> List Delivery -> List Delivery
deliveriesOfCluster cluster deliveries =
    deliveries |> List.filter (\delivery -> delivery.cluster == cluster)


parseCoordinates : String -> String -> Result String Coordinates
parseCoordinates latitudeString longitudeString =
    let
        maybeLatitude =
            String.toFloat (String.trim latitudeString)

        maybeLongitude =
            String.toFloat (String.trim longitudeString)
    in
    case ( maybeLatitude, maybeLongitude ) of
        ( Just latitude, Just longitude ) ->
            Ok (Coordinates latitude longitude)

        _ ->
            Err "Could not parse latitude or longitude"


allCoordinatesSet : Deliveries -> Bool
allCoordinatesSet deliveries =
    List.all
        (\delivery ->
            case delivery.coordinates of
                FetchSuccess _ ->
                    True

                SetManually ( _, Ok _ ) ->
                    True

                _ ->
                    False
        )
        (Dict.values deliveries)


nextDeliveryToFetchCoordinates : Deliveries -> Maybe Delivery
nextDeliveryToFetchCoordinates deliveries =
    let
        deliveryReadyToFetch : Delivery -> Bool
        deliveryReadyToFetch delivery =
            delivery.coordinates == NotFetched
    in
    deliveries |> Dict.values |> List.filter deliveryReadyToFetch |> List.head


decodeCsvRecordToDelivery : List String -> Int -> List String -> Result String Delivery
decodeCsvRecordToDelivery headers lineNumber record =
    let
        -- increment by 2 for header and to start from 1
        lineNumberString =
            String.fromInt (lineNumber + 2)

        recordArray =
            Array.fromList record

        recordDict =
            headers
                |> List.indexedMap (\index header -> ( index, header ))
                |> List.foldl
                    (\( index, header ) acc ->
                        case Array.get index recordArray of
                            Just value ->
                                ( header, value ) :: acc

                            Nothing ->
                                acc
                    )
                    []
                |> Dict.fromList

        maybeStreet =
            recordDict
                |> Dict.get streetKey

        maybeCity =
            recordDict
                |> Dict.get cityKey

        maybeSlot =
            recordDict
                |> Dict.get slotKey
    in
    case maybeStreet of
        Just _ ->
            case maybeCity of
                Just _ ->
                    case maybeSlot of
                        Just _ ->
                            Ok (Delivery lineNumber recordDict NotFetched 0)

                        _ ->
                            Err ("Lieferzeit fehlt - Linie " ++ lineNumberString)

                _ ->
                    Err ("Ort fehlt - Linie " ++ lineNumberString)

        _ ->
            Err ("Strasse fehlt - Linie " ++ lineNumberString)


decodeCsvToDeliveries : String -> Result String ( List String, List Delivery )
decodeCsvToDeliveries rawCsv =
    let
        csv =
            Csv.parse rawCsv

        deliveries =
            List.indexedMap (decodeCsvRecordToDelivery csv.headers) csv.records
    in
    if List.any Result.Extra.isErr deliveries then
        Err
            (String.join
                "\n"
                (List.foldl
                    (\deliveryResult acc ->
                        case deliveryResult of
                            Ok _ ->
                                acc

                            Err error ->
                                error :: acc
                    )
                    []
                    deliveries
                )
            )

    else
        Ok
            ( csv.headers
            , List.foldl
                (\deliveryResult acc ->
                    case deliveryResult of
                        Ok delivery ->
                            delivery :: acc

                        Err _ ->
                            acc
                )
                []
                deliveries
            )


encodeDeliveriesToCsv : List String -> Deliveries -> String
encodeDeliveriesToCsv headers deliveries =
    let
        quoteValue : String -> String
        quoteValue value =
            "\"" ++ String.replace "\"" "" value ++ "\""

        headersLine =
            headers
                |> List.map (\header -> quoteValue header)
                |> String.join ","

        deliveriesLines =
            Dict.values deliveries
                |> List.map
                    (\delivery ->
                        headers
                            |> List.map (\header -> quoteValue (getValue header delivery))
                            |> String.join ","
                    )
    in
    String.join "\n" (headersLine :: deliveriesLines)


clusterDeliveries : Int -> Deliveries -> Deliveries
clusterDeliveries nClusters deliveries =
    List.foldl (\slot acc -> clusterSlot nClusters slot acc)
        deliveries
        (slotsOfDeliveries deliveries)


clusterSlot : Int -> String -> Deliveries -> Deliveries
clusterSlot nClusters slot deliveries =
    let
        clusteredDeliveries =
            KMeans.clusterBy toVector nClusters (deliveriesOfSlot slot deliveries)

        toVector : Delivery -> List Float
        toVector delivery =
            case deliveryCoordinates delivery of
                Just coordinates ->
                    [ coordinates.latitude, coordinates.longitude ]

                _ ->
                    []

        clusteredDeliveriesDict =
            clusteredDeliveries.clusters
                |> List.indexedMap (\index deliveriesOfCurrentCluster -> List.map (\delivery -> { delivery | cluster = index }) deliveriesOfCurrentCluster)
                |> List.concat
                |> List.map (\delivery -> ( delivery.id, delivery ))
                |> Dict.fromList
    in
    Dict.union clusteredDeliveriesDict deliveries


updateDelivery : String -> String -> Int -> Deliveries -> Result String Deliveries
updateDelivery key value id deliveries =
    case Dict.get id deliveries of
        Just delivery ->
            let
                updatedDelivery =
                    setValue key value delivery
            in
            Ok (Dict.insert id updatedDelivery deliveries)

        Nothing ->
            Err "delivery not found"


setValue : String -> String -> Delivery -> Delivery
setValue key value delivery =
    let
        -- set coordinates to NotFetched if city or street changes
        coordinates =
            if key == streetKey || key == cityKey then
                NotFetched

            else
                delivery.coordinates
    in
    { delivery
        | csvRecords = Dict.insert key value delivery.csvRecords
        , coordinates = coordinates
    }


getCity : Delivery -> String
getCity delivery =
    getValue cityKey delivery


getStreet : Delivery -> String
getStreet delivery =
    getValue streetKey delivery


getSlot : Delivery -> String
getSlot delivery =
    getValue slotKey delivery


getValue : String -> Delivery -> String
getValue key delivery =
    Dict.get key delivery.csvRecords |> Maybe.withDefault ""


checkIfDeliveryNearby : Delivery -> Delivery -> Bool
checkIfDeliveryNearby lhs rhs =
    case ( deliveryCoordinates lhs, deliveryCoordinates rhs ) of
        ( Just lhsCoordinates, Just rhsCoordinates ) ->
            abs (lhsCoordinates.longitude - rhsCoordinates.longitude) <= 0.00005 && abs (lhsCoordinates.latitude - rhsCoordinates.latitude) <= 0.00005

        _ ->
            False
