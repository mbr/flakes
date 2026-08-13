module Main exposing (main)

{-| Runs the browser application and demonstrates the API boundary.
-}

import Api
import Browser
import Browser.Navigation as Navigation
import ChadCn.Alert as Alert
import ChadCn.Button as Button
import Html exposing (Html, div, h1, main_, p, text)
import Html.Attributes exposing (attribute, class)
import RemoteData exposing (RemoteData(..))


{-| Supplies values generated with the loaded frontend.
-}
type alias Flags =
    { frontendVersion : String
    }


{-| Tracks whether the loaded frontend matches the served frontend.
-}
type FrontendVersion
    = Current String
    | Outdated
        { latestVersion : String
        , loadedVersion : String
        }


{-| Holds the application state.
-}
type alias Model =
    { frontendVersion : FrontendVersion
    , status : RemoteData Api.Error Api.Status
    }


{-| Describes browser application events.
-}
type Msg
    = ApiCompleted (Api.Completion Msg)
    | ReceivedStatus (Result Api.Error Api.Status)
    | ReloadRequested
    | Retried


{-| Creates the browser application state.
-}
init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { frontendVersion = Current flags.frontendVersion
      , status = Loading
      }
    , Api.getStatus ReceivedStatus ApiCompleted
    )


{-| Applies one browser application event.
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        ApiCompleted completion ->
            update completion.originalMessage
                { model
                    | frontendVersion =
                        observeFrontendVersion
                            completion.frontendVersion
                            model.frontendVersion
                }

        ReceivedStatus result ->
            ( { model | status = RemoteData.fromResult result }, Cmd.none )

        ReloadRequested ->
            ( model, Navigation.reload )

        Retried ->
            ( { model | status = Loading }
            , Api.getStatus ReceivedStatus ApiCompleted
            )


{-| Records a mismatch without allowing later responses to clear it.
-}
observeFrontendVersion : String -> FrontendVersion -> FrontendVersion
observeFrontendVersion latestVersion frontendVersion =
    case frontendVersion of
        Current loadedVersion ->
            if loadedVersion == latestVersion then
                frontendVersion

            else
                Outdated
                    { latestVersion = latestVersion
                    , loadedVersion = loadedVersion
                    }

        Outdated _ ->
            frontendVersion


{-| Renders the browser application.
-}
view : Model -> Html Msg
view model =
    main_
        [ class "flex min-h-screen items-center justify-center bg-background p-6 text-foreground" ]
        [ div [ class "w-full max-w-md space-y-6" ]
            [ viewFrontendVersion model.frontendVersion
            , div [ class "space-y-2" ]
                [ h1 [ class "text-3xl font-semibold tracking-tight" ] [ text "Rust + Elm" ]
                , p [ class "text-sm text-muted-foreground" ]
                    [ text "A typed full-stack application is ready." ]
                ]
            , viewStatus model.status
            ]
        ]


{-| Renders a prompt when a newer frontend is available.
-}
viewFrontendVersion : FrontendVersion -> Html Msg
viewFrontendVersion frontendVersion =
    case frontendVersion of
        Current _ ->
            text ""

        Outdated _ ->
            Alert.new
                [ Alert.title [ text "Update available" ]
                , Alert.description [ text "Reload to use the latest version of the application." ]
                , Alert.action
                    [ Button.new [ text "Reload" ]
                        |> Button.withOnClick ReloadRequested
                        |> Button.withSize Button.Small
                        |> Button.withVariant Button.Outline
                        |> Button.view
                    ]
                ]
                |> Alert.view


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
                    [ text
                        ("Status: "
                            ++ serviceStatus.status
                            ++ ", database: "
                            ++ (if serviceStatus.databaseReady then
                                    "ready"

                                else
                                    "unavailable"
                               )
                        )
                    ]
                ]


{-| Subscribes to browser events.
-}
subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


{-| Starts the browser application.
-}
main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }
