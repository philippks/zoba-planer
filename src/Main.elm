port module Main exposing (..)

import Browser
import Delivery exposing (..)
import Dict exposing (Dict)
import Element exposing (Element, column, el, fill, height, htmlAttribute, layout, padding, paddingEach, paragraph, px, rgb, row, shrink, spacing, spacingXY, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.HexColor exposing (rgbCSSHex)
import Element.Input as Input
import Element.Region
import File.Download
import Html exposing (Html, div)
import Html.Attributes exposing (class, id)
import Osm exposing (OsmQueryResult, houseCoordinatesFromOsmResponse, queryOsm)
import Time
import UI exposing (info, primaryButton, secondaryButton, warning)


main : Program (List ( String, ( String, Coordinates ) )) Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type alias Model =
    { drivers : Int
    , inputCsv : String
    , parsedCsvHeaders : List String
    , deliveries : Deliveries
    , parseCsvError : Maybe String
    , progress : Progress
    , cachedCoordinates : CoordinatesCache
    , headquarterCoordinates : Coordinates
    , headquarterCoordinatesString : String
    , headquarterCoordinatesError : Maybe String
    }


type Progress
    = Input
    | FetchCoordinates
    | PrepareClustering
    | ClusterDeliveries (Maybe String)
    | RenderRoutes Deliveries


type alias CoordinatesCache =
    Dict String ( String, Coordinates )


type alias CoordinatesByClusterAndSlot =
    List ( String, List ( Int, List ( Int, Coordinates ) ) )


type AddMarkersMode
    = InitialAddMarkers
    | UpdateMarkers


init : List ( String, ( String, Coordinates ) ) -> ( Model, Cmd Msg )
init cachedCoordinatesList =
    let
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

        cachedCoordinates =
            Dict.fromList cachedCoordinatesList

        headquarterCoordinates =
            Coordinates 47.25229 8.77175
    in
    ( Model drivers
        input
        []
        Dict.empty
        Nothing
        Input
        cachedCoordinates
        headquarterCoordinates
        "47.25229,8.77175"
        Nothing
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Time.every 2000 Tick
        , markerClicked MarkerClicked
        ]



-- PORTS


port setCachedCoordinates : List ( String, ( String, Coordinates ) ) -> Cmd msg


port initMap : (Coordinates) -> Cmd msg


port clearMap : () -> Cmd msg


port initRenderRouteMaps : ( Coordinates, CoordinatesByClusterAndSlot ) -> Cmd msg


port addMarkers : ( String, Coordinates, List ( Int, Coordinates, Int ) ) -> Cmd msg


port markerClicked : (Int -> msg) -> Sub msg



--- UPDATE


type Msg
    = InputCsv String
    | SubmitCsv
    | QueryOsm Delivery
    | GotOsmResponse Delivery OsmQueryResult
    | DeliveryChanged ( Int, String, String )
    | SetCoordinatesManually Delivery String
    | CancelSetCoordinatesManually Delivery
    | Tick Time.Posix
    | DownloadDeliveriesCsv
    | SetDrivers Float
    | SetHeadquarterCoordinates String
    | SubmitCoordinates
    | StartClustering
    | SlotButtonClicked String
    | AddMarkers ( AddMarkersMode, List Delivery )
    | MarkerClicked Int
    | BackTo Progress
    | SubmitClusters


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        InputCsv inputCsv ->
            ( { model | inputCsv = inputCsv, parseCsvError = Nothing }, Cmd.none )

        SubmitCsv ->
            case decodeCsvToDeliveries model.inputCsv of
                Err error ->
                    ( { model | parseCsvError = Just ("Fehler in der Eingabe:\n" ++ error) }, Cmd.none )

                Ok ( _, [] ) ->
                    ( { model | parseCsvError = Just "Füge die Bestellungen oben ein" }, Cmd.none )

                Ok ( headers, listOfDeliveries ) ->
                    let
                        deliveries =
                            listOfDeliveries
                                |> List.map (setCoordinatesFromCache model.cachedCoordinates)
                                |> List.map (\delivery -> ( delivery.id, delivery ))
                                |> Dict.fromList
                    in
                    ( { model
                        | parsedCsvHeaders = headers
                        , deliveries = deliveries
                        , progress = FetchCoordinates
                      }
                    , Cmd.none
                    )

        QueryOsm delivery ->
            let
                deliveryWithCachedCoordinates =
                    setCoordinatesFromCache model.cachedCoordinates delivery
            in
            case deliveryWithCachedCoordinates.coordinates of
                FetchSuccess _ ->
                    ( { model | deliveries = Dict.insert delivery.id deliveryWithCachedCoordinates model.deliveries }, Cmd.none )

                _ ->
                    ( { model | deliveries = setDeliveryCoordinates delivery.id Fetching model.deliveries }
                    , queryOsm delivery (getStreet delivery) (getCity delivery) GotOsmResponse
                    )

        GotOsmResponse delivery result ->
            let
                coordinatesStatus =
                    coordinatesFromOsmResponse result

                updatedDeliveries =
                    Dict.update delivery.id (Maybe.map (\deliveryInDict -> { deliveryInDict | coordinates = coordinatesStatus })) model.deliveries

                updatedCachedCoordinates =
                    case coordinatesStatus of
                        FetchSuccess coordinates ->
                            Dict.insert (deliveryCacheKey delivery) ( "FetchSuccess", coordinates ) model.cachedCoordinates

                        _ ->
                            model.cachedCoordinates
            in
            ( { model
                | deliveries = updatedDeliveries
                , cachedCoordinates = updatedCachedCoordinates
              }
            , setCachedCoordinates (Dict.toList updatedCachedCoordinates)
            )

        DeliveryChanged ( id, key, value ) ->
            case updateDelivery key value id model.deliveries of
                Ok deliveries ->
                    ( { model | deliveries = deliveries }, Cmd.none )

                -- do not handle errors yet
                Err _ ->
                    ( model, Cmd.none )

        SetCoordinatesManually delivery input ->
            let
                coordinatesStatus =
                    SetManually ( input, coordinatesFromManualInput input )

                updatedDeliveries =
                    Dict.insert delivery.id { delivery | coordinates = coordinatesStatus } model.deliveries

                updatedCachedCoordinates =
                    case coordinatesStatus of
                        SetManually ( _, Ok coordinates ) ->
                            Dict.insert (deliveryCacheKey delivery) ( "SetManually", coordinates ) model.cachedCoordinates

                        _ ->
                            model.cachedCoordinates
            in
            ( { model
                | deliveries = updatedDeliveries
                , cachedCoordinates = updatedCachedCoordinates
              }
            , setCachedCoordinates (Dict.toList updatedCachedCoordinates)
            )

        CancelSetCoordinatesManually delivery ->
            let
                updatedDeliveries =
                    Dict.insert delivery.id { delivery | coordinates = NotFetched } model.deliveries

                updatedCachedCoordinates =
                    Dict.remove (deliveryCacheKey delivery) model.cachedCoordinates
            in
            ( { model
                | deliveries = updatedDeliveries
                , cachedCoordinates = updatedCachedCoordinates
              }
            , setCachedCoordinates (Dict.toList updatedCachedCoordinates)
            )

        Tick _ ->
            case nextDeliveryToFetchCoordinates model.deliveries of
                Just delivery ->
                    update (QueryOsm delivery) model

                _ ->
                    ( model, Cmd.none )

        DownloadDeliveriesCsv ->
            ( model, File.Download.string "Bestellungen.csv" "text/csv" (encodeDeliveriesToCsv model.parsedCsvHeaders model.deliveries) )

        SubmitCoordinates ->
            ( { model | progress = PrepareClustering }, Cmd.none )

        SetDrivers drivers ->
            ( { model | drivers = round drivers }, Cmd.none )

        SetHeadquarterCoordinates headquarterCoordinatesString ->
            case coordinatesFromManualInput headquarterCoordinatesString of
                Ok coordinates ->
                    ( { model
                        | headquarterCoordinatesString = headquarterCoordinatesString
                        , headquarterCoordinates = coordinates
                        , headquarterCoordinatesError = Nothing
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model
                        | headquarterCoordinatesString = headquarterCoordinatesString
                        , headquarterCoordinatesError = Just error
                      }
                    , Cmd.none
                    )

        StartClustering ->
            ( { model | progress = ClusterDeliveries Nothing, deliveries = clusterDeliveries model.drivers model.deliveries }, initMap (model.headquarterCoordinates) )

        SlotButtonClicked slot ->
            update
                (AddMarkers
                    ( InitialAddMarkers
                    , deliveriesOfSlot slot model.deliveries
                    )
                )
                { model | progress = ClusterDeliveries (Just slot) }

        BackTo progress ->
            ( { model | progress = progress }
            , case progress of
                ClusterDeliveries _ ->
                    initMap (model.headquarterCoordinates)

                _ ->
                    clearMap ()
            )

        AddMarkers ( mode, deliveries ) ->
            let
                appendDeliveryInfo : Delivery -> List ( Int, Coordinates, Int ) -> List ( Int, Coordinates, Int )
                appendDeliveryInfo delivery acc =
                    case deliveryCoordinates delivery of
                        Just coordinates ->
                            ( delivery.id, coordinates, delivery.cluster ) :: acc

                        _ ->
                            acc

                deliveriesCoordinatesWithCluster =
                    List.foldl appendDeliveryInfo [] deliveries

                modeString : String
                modeString =
                    case mode of
                        InitialAddMarkers ->
                            "initial"

                        UpdateMarkers ->
                            "update"
            in
            ( model, addMarkers ( modeString, model.headquarterCoordinates, deliveriesCoordinatesWithCluster ) )

        MarkerClicked id ->
            -- if a marker was clicked, change the cluster of the corresponding
            -- delivery and all nearby deliveries - this is especially
            -- important when the deliveries overlap each other
            case Dict.get id model.deliveries of
                Just clickedDelivery ->
                    let
                        nearbyDeliveries =
                            model.deliveries
                                |> Dict.values
                                |> List.filter (checkIfDeliveryNearby clickedDelivery)

                        newCluster =
                            modBy model.drivers (clickedDelivery.cluster + 1)

                        updatedDeliveries =
                            Dict.union
                                (nearbyDeliveries
                                    |> List.map (\delivery -> { delivery | cluster = newCluster })
                                    |> List.map (\delivery -> ( delivery.id, delivery ))
                                    |> Dict.fromList
                                )
                                model.deliveries

                        updatedDeliveriesOfSlot =
                            deliveriesOfSlot (getSlot clickedDelivery) updatedDeliveries
                    in
                    update (AddMarkers ( UpdateMarkers, updatedDeliveriesOfSlot )) { model | deliveries = updatedDeliveries }

                _ ->
                    ( model, Cmd.none )

        SubmitClusters ->
            let
                slots =
                    slotsOfDeliveries model.deliveries

                deliveriesOfSlotByCluster slot deliveries =
                    List.range 0 (model.drivers - 1)
                        |> List.map
                            (\cluster ->
                                ( cluster
                                , deliveries
                                    |> deliveriesOfSlot slot
                                    |> deliveriesOfCluster cluster
                                    |> deliveriesCoordinates
                                )
                            )
                        |> List.filter (\( _, deliveriesOfCurrentCluster ) -> List.length deliveriesOfCurrentCluster > 0)

                coordinatesByClustersAndSlots : CoordinatesByClusterAndSlot
                coordinatesByClustersAndSlots =
                    slots
                        |> List.map
                            (\slot ->
                                ( slot, deliveriesOfSlotByCluster slot model.deliveries )
                            )
            in
            ( { model | progress = RenderRoutes model.deliveries }, initRenderRouteMaps ( model.headquarterCoordinates, coordinatesByClustersAndSlots ) )


deliveryCacheKey : Delivery -> String
deliveryCacheKey delivery =
    getStreet delivery ++ " " ++ getCity delivery


setNotFetchedCoordinatesFromCache : CoordinatesCache -> List Delivery -> List Delivery
setNotFetchedCoordinatesFromCache cachedCoordinates listOfDeliveries =
    listOfDeliveries
        |> List.map (setCoordinatesFromCache cachedCoordinates)


setCoordinatesFromCache : CoordinatesCache -> Delivery -> Delivery
setCoordinatesFromCache cachedCoordinates delivery =
    case Dict.get (deliveryCacheKey delivery) cachedCoordinates of
        -- coordinates of delivery have been cached
        Just ( "FetchSuccess", coordinates ) ->
            { delivery | coordinates = FetchSuccess coordinates }

        Just ( "SetManually", coordinates ) ->
            { delivery | coordinates = SetManually ( coordinatesString coordinates, Ok coordinates ) }

        _ ->
            delivery



--- VIEW


view : Model -> Html Msg
view model =
    div []
        [ case model.progress of
            Input ->
                layout [ padding 30 ] <|
                    column [ width fill, spacing 10 ]
                        [ el [ width fill, Element.Region.heading 1, Font.size 48 ] (text "Bestellungen erfassen")
                        , info <|
                            column [ spacing 20 ]
                                [ paragraph [] [ text "Erfasse als Erstes die Bestellungen im CSV Format." ]
                                , paragraph [] [ text """Wichtig ist, dass die Spalten "Strasse", "Ort" und "Lieferzeit" vorhanden sind. Weitere Spalten können frei gewählt werden, wobei diese dann auf den finalen Routen für Fahrer sein werden (z.B. "Telefonnummer", "Bemerkungen", etc).""" ]
                                ]
                        , Input.multiline []
                            { label = Input.labelHidden "Bestellungen"
                            , text = model.inputCsv
                            , onChange = InputCsv
                            , placeholder = Nothing
                            , spellcheck = False
                            }
                        , case model.parseCsvError of
                            Just errors ->
                                warning <| column [ spacing 5 ] (List.map (\error -> text error) (String.lines errors))

                            Nothing ->
                                Element.none
                        , UI.primaryButton
                            { onPress = Just SubmitCsv, label = text "Bestellungen erfassen" }
                        ]

            FetchCoordinates ->
                layout [ padding 30 ] <|
                    column [ width fill, spacing 10 ]
                        [ el [ width fill, Element.Region.heading 1, Font.size 48 ] (text "Koordinaten setzen")
                        , info <|
                            column [ spacing 20 ]
                                [ paragraph [] [ text "Nun müssen für alle Bestellungen die Koordinaten gesetzt werden." ]
                                , paragraph [] [ text "Es wird versucht, diese automatisch zu finden. Falls das geklappt hat, wird die Bestellung grün markiert." ]
                                , paragraph [] [ text "Klappt es nicht, wird die Bestellung rot markiert. Überprüfe die Adresse und passe sie allenfalls an." ]
                                , paragraph []
                                    [ text "Klappt auch das nicht, suche die Koordinaten manuell auf "
                                    , Element.newTabLink []
                                        { url = "https://map.geo.admin.ch"
                                        , label = text "Swisstopo (hier)"
                                        }
                                    , text " und trage Sie bei der entsprechenden Bestellung ein. Beispiel: 47.2534, 8.7726"
                                    ]
                                ]
                        , viewDeliveries model.parsedCsvHeaders model.deliveries
                        , info <|
                            column [ spacing 10 ]
                                [ text "Lade die Bestellungen und alle gemachten Änderungen herunter, bevor du fortfährst."
                                , UI.primaryButton { onPress = Just DownloadDeliveriesCsv, label = text "Bestellungen herunterladen" }
                                ]
                        , row [ spacing 10 ]
                            [ UI.secondaryButton { onPress = Just (BackTo Input), label = text "Zurück" }
                            , if allCoordinatesSet model.deliveries then
                                UI.primaryButton { onPress = Just SubmitCoordinates, label = text "Weiter" }

                              else
                                warning <|
                                    paragraph [] [ text "Du kannst erst fortfahren, wenn die Koordinaten von allen Bestellungen gesetzt sind." ]
                            ]
                        ]

            PrepareClustering ->
                layout [ padding 30 ] <|
                    column [ spacing 10 ]
                        [ el [ width fill, Element.Region.heading 1, Font.size 48 ] (text "Planung vorbereiten")
                        , info <| paragraph [] [ text "Für die Routenplanung wird noch die Anzahl Fahrer und die Koordinaten des Standorts, von wo die Fahrer starten, benötigt." ]
                        , Input.slider
                            [ height (px 30)
                            , width (fill |> Element.maximum 600)
                            , Element.behindContent
                                (Element.el
                                    [ width fill
                                    , height (px 2)
                                    , Element.centerY
                                    , Background.color (rgb 0 0 0)
                                    , Border.rounded 2
                                    ]
                                    Element.none
                                )
                            ]
                            { step = Just 1
                            , min = 1
                            , max = 10
                            , value = toFloat model.drivers
                            , onChange = SetDrivers
                            , label = Input.labelAbove [] (text ("Anzahl Fahrer: " ++ String.fromInt model.drivers))
                            , thumb = Input.defaultThumb
                            }
                        , Input.text []
                            { text = model.headquarterCoordinatesString
                            , onChange = \value -> SetHeadquarterCoordinates value
                            , placeholder = Nothing
                            , label = Input.labelAbove [] (text "Koordinaten von wo die Fahrer starten")
                            }
                        , row [ spacing 10 ]
                            [ UI.secondaryButton { onPress = Just (BackTo FetchCoordinates), label = text "Zurück" }
                            , case model.headquarterCoordinatesError of
                                Nothing ->
                                    UI.primaryButton { onPress = Just StartClustering, label = text "Weiter" }

                                _ ->
                                    warning <| text "Ungültige Koordinaten"
                            ]
                        ]

            ClusterDeliveries maybeSlot ->
                layout [ padding 30 ] <|
                    column [ width fill, spacing 10 ]
                        [ el [ width fill, Element.Region.heading 1, Font.size 48 ] (text "Routen planen")
                        , info <| paragraph [] [ text """Plane nun für jede Lieferzeit die Routen.
Die Bestellungen wurden bereits einer Route zugeordnet, wobei jede Route jeweils eine Farbe ist.
Die Routen sind aber nicht perfekt und müssen überprüft werden.
Indem du auf eine der Bestellung klickst, kannst du diese einer anderen Route zuordnen.""" ]
                        , row [ spacing 20 ]
                            [ slotButtons maybeSlot model.deliveries
                            , case maybeSlot of
                                Just slot ->
                                    currentClusterStats slot model.deliveries

                                _ ->
                                    Element.none
                            ]
                        , el [ Element.htmlAttribute <| id "map", height <| px 600, width fill ] (text "render map here")
                        , row [ spacing 10 ]
                            [ UI.secondaryButton { onPress = Just (BackTo PrepareClustering), label = text "Zurück" }
                            , UI.primaryButton { onPress = Just SubmitClusters, label = text "Weiter" }
                            ]
                        ]

            RenderRoutes deliveries ->
                -- we've to use HTML instead of elm-ui here, because flex boxes do not support page breaks
                div []
                    [ viewRoutes model.parsedCsvHeaders deliveries
                    , div [ class "no-print" ]
                        [ layout [] <|
                            row [ spacing 10 ]
                                [ UI.secondaryButton { onPress = Just (BackTo <| ClusterDeliveries Nothing), label = text "Zurück" }
                                ]
                        ]
                    ]
        ]


slotButtons : Maybe String -> Deliveries -> Element Msg
slotButtons maybeActiveSlot deliveries =
    let
        buttonStyle slot =
            case maybeActiveSlot of
                Just activeSlot ->
                    if activeSlot == slot then
                        primaryButton

                    else
                        secondaryButton

                _ ->
                    secondaryButton

        slotButton : String -> Element Msg
        slotButton slot =
            buttonStyle slot
                { label = text slot
                , onPress = Just (SlotButtonClicked slot)
                }
    in
    row [ spacing 5 ] <| List.map slotButton (slotsOfDeliveries deliveries)


currentClusterStats : String -> Deliveries -> Element Msg
currentClusterStats slot deliveries =
    let
        deliveriesOfCurrentSlot =
            deliveriesOfSlot slot deliveries

        clusters =
            clustersOfDeliveries deliveriesOfCurrentSlot

        nDelivieriesOfCluster cluster =
            deliveriesOfCurrentSlot
                |> deliveriesOfCluster cluster
                |> List.length
                |> String.fromInt
    in
    row [ spacing 5 ]
        (text "Anzahl Auslieferungen pro Route: "
            :: (clusters
                    |> List.map
                        (\cluster ->
                            el [ Font.bold, htmlAttribute <| class ("cluster-" ++ (String.fromInt <| cluster)) ]
                                (text (nDelivieriesOfCluster cluster))
                        )
                    |> List.intersperse (text "|")
               )
        )


viewDeliveries : List String -> Deliveries -> Element Msg
viewDeliveries headers deliveries =
    Element.table [ spacing 10, paddingEach { top = 0, left = 0, right = 10, bottom = 0 } ]
        { data = deliveries |> Dict.values
        , columns =
            (headers
                |> List.map
                    (\header ->
                        { header = el [ Font.bold ] (text header)
                        , width =
                            if header == Delivery.streetKey then
                                px 250

                            else if header == Delivery.cityKey then
                                px 200

                            else
                                fill
                        , view =
                            \delivery ->
                                Input.text []
                                    { text = getValue header delivery
                                    , onChange = \value -> DeliveryChanged ( delivery.id, header, value )
                                    , placeholder = Nothing
                                    , label = Input.labelHidden header
                                    }
                        }
                    )
            )
                ++ [ { header = el [ Font.bold ] (text "Koordinaten")
                     , width = px 250
                     , view = viewCoordinatesStatus
                     }
                   ]
        }


viewCoordinatesStatus : Delivery -> Element Msg
viewCoordinatesStatus delivery =
    let
        borderColor : String
        borderColor =
            case delivery.coordinates of
                FetchSuccess _ ->
                    "#58c458"

                SetManually ( _, Ok _ ) ->
                    "#58c458"

                SetManually ( _, Err _ ) ->
                    "#d39c48"

                FetchError _ ->
                    "#d39c48"

                _ ->
                    "#FFFFFF"
    in
    el [ Element.centerY, Border.widthEach { top = 0, bottom = 0, left = 0, right = 5 }, Border.color <| rgbCSSHex borderColor ] <|
        case delivery.coordinates of
            NotFetched ->
                text "Wird gesucht..."

            Fetching ->
                text "Wird gesucht..."

            FetchSuccess coordinates ->
                row []
                    [ text "Gefunden "
                    , coordinatesLink coordinates
                    ]

            FetchError error ->
                column [ spacing 5 ]
                    [ warning <| paragraph [] [ text error ]
                    , paragraph [] [ text "Korrigiere die Adresse oder setzte die Koordinaten manuell" ]
                    , UI.secondaryButton
                        { onPress = Just (SetCoordinatesManually delivery "")
                        , label = text "Manuell setzen"
                        }
                    ]

            SetManually ( value, result ) ->
                column [ spacing 5 ]
                    [ Input.text []
                        { onChange = SetCoordinatesManually delivery
                        , text = value
                        , placeholder = Just (Input.placeholder [] (text "z.B. 47.2534, 8.7726"))
                        , label = Input.labelAbove [] (text "Koordinaten manuell setzen:")
                        }
                    , case ( value, result ) of
                        ( _, Ok _ ) ->
                            Element.none

                        ( "", Err _ ) ->
                            Element.none

                        _ ->
                            warning <| text "Ungültige Koordinaten"
                    , UI.secondaryButton
                        { onPress = Just (CancelSetCoordinatesManually delivery)
                        , label = text "Abbrechen"
                        }
                    ]


coordinatesString : Coordinates -> String
coordinatesString coordinates =
    String.fromFloat coordinates.latitude ++ "," ++ String.fromFloat coordinates.longitude


coordinatesLink : Coordinates -> Element Msg
coordinatesLink coordinates =
    let
        latitudeString =
            String.fromFloat coordinates.latitude

        longitudeString =
            String.fromFloat coordinates.longitude
    in
    Element.newTabLink []
        { url = "https://www.openstreetmap.org/query?mlat=" ++ latitudeString ++ "&mlon=" ++ longitudeString ++ "#map=19/" ++ latitudeString ++ "/" ++ longitudeString
        , label = text "(👁)"
        }


viewRoutes : List String -> Deliveries -> Html Msg
viewRoutes headers deliveries =
    div [ class "page-wrap" ]
        (List.map
            (\slot ->
                let
                    deliveriesOfCurrentSlot =
                        deliveriesOfSlot slot deliveries
                in
                div []
                    (List.map
                        (\cluster ->
                            let
                                title =
                                    "Lieferzeit " ++ slot ++ ", Fahrer: " ++ String.fromInt (cluster + 1)

                                mapId =
                                    "map-" ++ String.replace " " "" slot ++ "-cluster-" ++ String.fromInt cluster

                                deliveriesOfCurrentCluster =
                                    deliveriesOfCluster cluster deliveriesOfCurrentSlot
                            in
                            div []
                                [ div []
                                    [ layout [] <|
                                        column []
                                            [ el [ width fill, Element.Region.heading 1, Font.size 18 ] (text title)
                                            , el [ htmlAttribute <| id mapId, htmlAttribute <| class "route-map-container", width <| px 1200, height <| px 450 ] (text "Render map here")
                                            ]
                                    ]
                                , div [ class "page-break" ]
                                    [ layout [] <|
                                        column [ padding 2, spacing 8, width fill, height fill ]
                                            [ viewRouteDeliveriesTable headers deliveriesOfCurrentCluster
                                            ]
                                    ]
                                ]
                        )
                        (clustersOfDeliveries deliveriesOfCurrentSlot)
                    )
            )
            (slotsOfDeliveries deliveries)
        )


viewRouteDeliveriesTable : List String -> List Delivery -> Element Msg
viewRouteDeliveriesTable headers deliveries =
    let
        tableHeader : String -> Element Msg
        tableHeader value =
            el
                [ Font.size 12
                , Font.bold
                ]
                (text value)

        tableValue : String -> Element Msg
        tableValue value =
            paragraph
                [ Font.size 12
                ]
                [ text value ]
    in
    Element.table [ spacingXY 15 2 ]
        { data = deliveries
        , columns =
            { header = tableHeader "ID"
            , width = shrink
            , view = \delivery -> tableValue <| String.fromInt delivery.id
            }
                :: (headers
                        |> List.map
                            (\header ->
                                { header = tableHeader header
                                , width = shrink
                                , view =
                                    \delivery ->
                                        tableValue <| getValue header delivery
                                }
                            )
                   )
        }


coordinatesFromOsmResponse : OsmQueryResult -> CoordinatesStatus
coordinatesFromOsmResponse result =
    case houseCoordinatesFromOsmResponse parseCoordinates result of
        Ok coordinates ->
            FetchSuccess coordinates

        Err error ->
            FetchError error


coordinatesFromManualInput : String -> Result String Coordinates
coordinatesFromManualInput input =
    case String.split "," input of
        [ latitudeString, longitudeString ] ->
            parseCoordinates latitudeString longitudeString

        _ ->
            Err "Falsches Format"
