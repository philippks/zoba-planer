module Pages.Home_ exposing (Model, Msg, page)

import App
import Dict
import Effect exposing (Effect)
import Html
import Page exposing (Page)
import Ports
import Route exposing (Route)
import Shared
import Time
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init shared
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- INIT


type alias Model =
    App.Model


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    let
        ( appModel, appCmd ) =
            App.init (Dict.toList shared.cachedCoordinates)
    in
    ( appModel
    , Effect.sendCmd (Cmd.map AppMsg appCmd)
    )



-- UPDATE


type Msg
    = AppMsg App.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        AppMsg appMsg ->
            let
                ( newModel, appCmd ) =
                    App.update appMsg model
            in
            ( newModel
            , Effect.sendCmd (Cmd.map AppMsg appCmd)
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map AppMsg (App.subscriptions model)



-- VIEW


view : Model -> View Msg
view model =
    { title = "Zoba Routenplaner"
    , body = [ Html.map AppMsg (App.view model) ]
    }
