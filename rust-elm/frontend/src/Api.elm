module Api exposing (Error(..), Problem, Status, errorMessage, getStatus)

{-| Defines the browser side of the HTTP transport contract.
-}

import Http
import Json.Decode as Decode exposing (Decoder)


{-| Describes the service status.
-}
type alias Status =
    { status : String
    }


{-| Describes an error returned by the JSON API.
-}
type alias Problem =
    { code : String
    , message : String
    }


{-| Describes failures produced while making an API request.
-}
type Error
    = BadUrl String
    | NetworkError
    | Timeout
    | Rejected
        { status : Int
        , problem : Maybe Problem
        , body : String
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
            rejection.problem
                |> Maybe.map .message
                |> Maybe.withDefault
                    ("The API rejected the request with status "
                        ++ String.fromInt rejection.status
                        ++ "."
                    )

        InvalidResponse _ ->
            "The API returned an unexpected response."


{-| Decodes successful JSON while preserving structured error responses.
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
            Err
                (Rejected
                    { body = body
                    , problem =
                        Decode.decodeString problemDecoder body
                            |> Result.toMaybe
                    , status = metadata.statusCode
                    }
                )

        Http.GoodStatus_ _ body ->
            Decode.decodeString decoder body
                |> Result.mapError (Decode.errorToString >> InvalidResponse)


{-| Decodes the service status contract.
-}
statusDecoder : Decoder Status
statusDecoder =
    Decode.map Status
        (Decode.field "status" Decode.string)


{-| Decodes the structured API error contract.
-}
problemDecoder : Decoder Problem
problemDecoder =
    Decode.map2 Problem
        (Decode.field "code" Decode.string)
        (Decode.field "message" Decode.string)
