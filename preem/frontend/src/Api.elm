module Api exposing (ApiProblem(..), Completion, Error(..), Pong, errorMessage, ping)

{-| Defines the browser side of the HTTP transport contract.

Successful `2xx` responses are decoded with an endpoint-specific decoder. A
non-`2xx` response is decoded as the shared `ApiProblem` sum type; transport and
protocol failures remain separate `Error` variants. Keep public problem variants
and payloads synchronized with `backend/src/api.rs`.

-}

import Dict
import Http
import Json.Decode as Decode exposing (Decoder)


{-| Describes a successful ping response.
-}
type alias Pong =
    { message : String
    }


{-| Associates an API result message with response-wide metadata.
-}
type alias Completion msg =
    { frontendVersion : String
    , originalMessage : msg
    }


{-| Describes failures returned by the JSON API.
-}
type ApiProblem
    = Internal
    | RouteNotFound
    | MethodNotAllowed


{-| Describes failures produced while making an API request.
-}
type Error
    = BadUrl String
    | NetworkError
    | Timeout
    | Rejected
        { status : Int
        , problem : ApiProblem
        }
    | InvalidResponse String


{-| Pings the API.
-}
ping : (Result Error Pong -> msg) -> (Completion msg -> msg) -> Cmd msg
ping toMessage toCompletion =
    Http.get
        { expect = expectJson pongDecoder toMessage toCompletion
        , url = "/api/ping"
        }


{-| Returns a default human-readable description of an API failure.
-}
errorMessage : Error -> String
errorMessage error =
    case error of
        BadUrl _ ->
            "The API address is invalid."

        NetworkError ->
            "The API could not be reached."

        Timeout ->
            "The API request timed out."

        Rejected rejection ->
            problemMessage rejection.problem

        InvalidResponse _ ->
            "The API returned an unexpected response."


{-| Returns a human-readable description of an API problem.
-}
problemMessage : ApiProblem -> String
problemMessage problem =
    case problem of
        Internal ->
            "The server could not complete the request."

        RouteNotFound ->
            "The requested API route does not exist."

        MethodNotAllowed ->
            "The API route does not accept this request method."


{-| Decodes successful JSON and typed API problems according to HTTP status.
-}
expectJson : Decoder value -> (Result Error value -> msg) -> (Completion msg -> msg) -> Http.Expect msg
expectJson decoder toMessage toCompletion =
    Http.expectStringResponse
        (dispatchCompletion toCompletion)
        (decodeResponse decoder toMessage)


{-| Dispatches either a transport failure or completed HTTP response.
-}
dispatchCompletion : (Completion msg -> msg) -> Result msg (Completion msg) -> msg
dispatchCompletion toCompletion completion =
    case completion of
        Err message ->
            message

        Ok completed ->
            toCompletion completed


{-| Decodes one HTTP response and preserves its frontend version.
-}
decodeResponse : Decoder value -> (Result Error value -> msg) -> Http.Response String -> Result msg (Completion msg)
decodeResponse decoder toMessage response =
    case response of
        Http.BadUrl_ url ->
            Err (toMessage (Err (BadUrl url)))

        Http.Timeout_ ->
            Err (toMessage (Err Timeout))

        Http.NetworkError_ ->
            Err (toMessage (Err NetworkError))

        Http.BadStatus_ metadata body ->
            Decode.decodeString apiProblemDecoder body
                |> Result.mapError (Decode.errorToString >> InvalidResponse)
                |> Result.andThen
                    (\problem ->
                        Err
                            (Rejected
                                { problem = problem
                                , status = metadata.statusCode
                                }
                            )
                    )
                |> completeResponse metadata toMessage

        Http.GoodStatus_ metadata body ->
            Decode.decodeString decoder body
                |> Result.mapError (Decode.errorToString >> InvalidResponse)
                |> completeResponse metadata toMessage


{-| Wraps an endpoint result with metadata shared by every API response.
-}
completeResponse : Http.Metadata -> (Result Error value -> msg) -> Result Error value -> Result msg (Completion msg)
completeResponse metadata toMessage result =
    case Dict.get "frontend-version" metadata.headers of
        Just frontendVersion ->
            Ok
                { frontendVersion = frontendVersion
                , originalMessage = toMessage result
                }

        Nothing ->
            Err
                (toMessage
                    (Err
                        (InvalidResponse "The API response is missing its frontend version.")
                    )
                )


{-| Decodes a successful ping response.
-}
pongDecoder : Decoder Pong
pongDecoder =
    Decode.map Pong
        (Decode.field "message" Decode.string)


{-| Decodes the public API problem sum type.
-}
apiProblemDecoder : Decoder ApiProblem
apiProblemDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\problemType ->
                case problemType of
                    "internal" ->
                        Decode.succeed Internal

                    "route_not_found" ->
                        Decode.succeed RouteNotFound

                    "method_not_allowed" ->
                        Decode.succeed MethodNotAllowed

                    _ ->
                        Decode.fail ("unknown API problem type: " ++ problemType)
            )
