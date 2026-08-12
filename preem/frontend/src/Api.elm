module Api exposing (ApiProblem(..), Error(..), Status, errorMessage, getStatus)

{-| Defines the browser side of the HTTP transport contract.

Successful `2xx` responses are decoded with an endpoint-specific decoder. A
non-`2xx` response is decoded as the shared `ApiProblem` sum type; transport and
protocol failures remain separate `Error` variants. Keep public problem variants
and payloads synchronized with `backend/src/api.rs`.

-}

import Http
import Json.Decode as Decode exposing (Decoder)


{-| Describes the service status.
-}
type alias Status =
    { databaseReady : Bool
    , status : String
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


{-| Fetches the current service status.
-}
getStatus : (Result Error Status -> msg) -> Cmd msg
getStatus toMessage =
    Http.get
        { expect = expectJson statusDecoder toMessage
        , url = "/api/status"
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
expectJson : Decoder value -> (Result Error value -> msg) -> Http.Expect msg
expectJson decoder toMessage =
    Http.expectStringResponse toMessage
        (decodeResponse decoder)


{-| Decodes one HTTP response into the application error model.
-}
decodeResponse : Decoder value -> Http.Response String -> Result Error value
decodeResponse decoder response =
    case response of
        Http.BadUrl_ url ->
            Err (BadUrl url)

        Http.Timeout_ ->
            Err Timeout

        Http.NetworkError_ ->
            Err NetworkError

        Http.BadStatus_ metadata body ->
            case Decode.decodeString apiProblemDecoder body of
                Ok problem ->
                    Err
                        (Rejected
                            { problem = problem
                            , status = metadata.statusCode
                            }
                        )

                Err decodeError ->
                    Err (InvalidResponse (Decode.errorToString decodeError))

        Http.GoodStatus_ _ body ->
            Decode.decodeString decoder body
                |> Result.mapError (Decode.errorToString >> InvalidResponse)


{-| Decodes the service status contract.
-}
statusDecoder : Decoder Status
statusDecoder =
    Decode.map2 Status
        (Decode.field "database_ready" Decode.bool)
        (Decode.field "status" Decode.string)


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
