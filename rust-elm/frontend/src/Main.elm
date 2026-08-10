module Main exposing (main)

{-| Runs the browser application and demonstrates the API boundary.
-}

import Api
import Browser
import ChadCn.Alert as Alert
import ChadCn.Button as Button
import Html exposing (Html, div, h1, main_, p, text)
import Html.Attributes exposing (attribute, class)
import RemoteData exposing (RemoteData(..))


{-| Holds the current API request state.
-}
type alias Model =
    { status : RemoteData Api.Error Api.Status
    }


{-| Describes browser application events.
-}
type Msg
    = ReceivedStatus (Result Api.Error Api.Status)
    | Retried


{-| Creates the browser application state.
-}
init : () -> ( Model, Cmd Msg )
init _ =
    ( { status = Loading }
    , Api.getStatus ReceivedStatus
    )


{-| Applies one browser application event.
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        ReceivedStatus result ->
            ( { model | status = RemoteData.fromResult result }, Cmd.none )

        Retried ->
            ( { model | status = Loading }
            , Api.getStatus ReceivedStatus
            )


{-| Renders the browser application.
-}
view : Model -> Html Msg
view model =
    main_
        [ class "flex min-h-screen items-center justify-center bg-background p-6 text-foreground" ]
        [ div [ class "w-full max-w-md space-y-6" ]
            [ div [ class "space-y-2" ]
                [ h1 [ class "text-3xl font-semibold tracking-tight" ] [ text "Rust + Elm" ]
                , p [ class "text-sm text-muted-foreground" ]
                    [ text "A typed full-stack application is ready." ]
                ]
            , viewStatus model.status
            ]
        ]


{-| Renders the current API request state.
-}
viewStatus : RemoteData Api.Error Api.Status -> Html Msg
viewStatus status =
    case status of
        NotAsked ->
            text ""

        Loading ->
            div
                [ attribute "aria-live" "polite"
                , attribute "role" "status"
                , class "rounded-lg border bg-card p-4 text-sm text-muted-foreground"
                ]
                [ text "Checking the API..." ]

        Failure error ->
            Alert.new
                [ Alert.title [ text "API unavailable" ]
                , Alert.description [ text (Api.errorMessage error) ]
                , Alert.action
                    [ Button.new [ text "Retry" ]
                        |> Button.withOnClick Retried
                        |> Button.withSize Button.Small
                        |> Button.withVariant Button.Outline
                        |> Button.view
                    ]
                ]
                |> Alert.withVariant Alert.Destructive
                |> Alert.view

        Success serviceStatus ->
            div
                [ class "rounded-lg border bg-card p-4 text-sm shadow-sm" ]
                [ p [ class "font-medium" ] [ text "API connected" ]
                , p [ class "mt-1 text-muted-foreground" ]
                    [ text ("Status: " ++ serviceStatus.status) ]
                ]


{-| Subscribes to browser events.
-}
subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


{-| Starts the browser application.
-}
main : Program () Model Msg
main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }
