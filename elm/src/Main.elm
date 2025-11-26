module Main exposing (main)

import Browser
import Html exposing (Html, button, div, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)


type alias Model =
    { count : Int
    }


init : Model
init =
    { count = 0
    }


type Msg
    = Increment
    | Decrement
    | Reset


update : Msg -> Model -> Model
update msg model =
    case msg of
        Increment ->
            { model | count = model.count + 1 }

        Decrement ->
            { model | count = model.count - 1 }

        Reset ->
            { model | count = 0 }


view : Model -> Html Msg
view model =
    div [ class "flex flex-col items-center justify-center min-h-screen bg-gray-100" ]
        [ div [ class "bg-white rounded-lg shadow-lg p-8 space-y-6" ]
            [ div [ class "text-6xl font-bold text-center text-gray-800" ]
                [ text (String.fromInt model.count) ]
            , div [ class "flex gap-3 justify-center" ]
                [ button
                    [ onClick Decrement
                    , class "px-6 py-3 bg-red-500 hover:bg-red-600 text-white rounded-lg font-semibold transition-colors"
                    ]
                    [ text "-" ]
                , button
                    [ onClick Increment
                    , class "px-6 py-3 bg-green-500 hover:bg-green-600 text-white rounded-lg font-semibold transition-colors"
                    ]
                    [ text "+" ]
                , button
                    [ onClick Reset
                    , class "px-6 py-3 bg-gray-500 hover:bg-gray-600 text-white rounded-lg font-semibold transition-colors"
                    ]
                    [ text "Reset" ]
                ]
            ]
        ]


main : Program () Model Msg
main =
    Browser.sandbox
        { init = init
        , update = update
        , view = view
        }
