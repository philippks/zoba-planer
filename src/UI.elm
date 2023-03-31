module UI exposing (info, primaryButton, secondaryButton, warning)

import Element exposing (Attribute, Element, el, fill, padding, rgb, rgba)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.HexColor exposing (rgbCSSHex)
import Element.Input as Input


info : Element msg -> Element msg
info content =
    Element.el
        [ Element.width <| fill
        , Element.padding 10
        , Font.color <| rgbCSSHex "#004085"
        , Background.color <| rgbCSSHex "#cce5ff"
        , Border.color <| rgbCSSHex "#b8daff"
        , Border.rounded 5
        ]
        content


warning : Element msg -> Element msg
warning content =
    el
        [ Element.width <| fill
        , Element.padding 10
        , Font.color <| rgbCSSHex "#856404"
        , Background.color <| rgbCSSHex "#fff3cd"
        , Border.color <| rgbCSSHex "#ffeeba"
        , Border.rounded 5
        ]
        content


primaryButton :
    { onPress : Maybe msg
    , label : Element msg
    }
    -> Element msg
primaryButton =
    Input.button
        [ Background.color <| rgbCSSHex "#0069d9"
        , Font.color <| rgb 255 255 255
        , Element.padding 15
        , Border.rounded 5
        ]


secondaryButton :
    { onPress : Maybe msg
    , label : Element msg
    }
    -> Element msg
secondaryButton =
    Input.button
        [ Background.color <| rgbCSSHex "#5a6268"
        , Font.color <| rgb 255 255 255
        , Element.padding 15
        , Border.rounded 5
        ]
