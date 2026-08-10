module ChadCn.Alert exposing
    ( Config
    , Variant(..)
    , action
    , description
    , new
    , title
    , view
    , withAttributes
    , withVariant
    )

{-| Provides a reusable alert component intended for extraction into a standalone package.

Ports the shadcn Base UI alert using the Nova style.

-}

import Html exposing (Attribute, Html, div)
import Html.Attributes exposing (attribute, class)


{-| Describes an alert and its presentation.
-}
type Config msg
    = Config
        { attributes : List (Attribute msg)
        , content : List (Html msg)
        , variant : Variant
        }


{-| Describes alert appearance.
-}
type Variant
    = Default
    | Destructive


{-| Creates a default alert with caller-owned content.
-}
new : List (Html msg) -> Config msg
new content =
    Config
        { attributes = []
        , content = content
        , variant = Default
        }


{-| Adds native attributes to the alert.
-}
withAttributes : List (Attribute msg) -> Config msg -> Config msg
withAttributes attributes (Config configuration) =
    Config { configuration | attributes = configuration.attributes ++ attributes }


{-| Sets the alert appearance.
-}
withVariant : Variant -> Config msg -> Config msg
withVariant variant (Config configuration) =
    Config { configuration | variant = variant }


{-| Renders alert title content.
-}
title : List (Html msg) -> Html msg
title content =
    div
        [ attribute "data-slot" "alert-title"
        , class "cn-alert-title [&_a]:underline [&_a]:underline-offset-3 [&_a]:hover:text-foreground"
        ]
        content


{-| Renders alert description content.
-}
description : List (Html msg) -> Html msg
description content =
    div
        [ attribute "data-slot" "alert-description"
        , class "cn-alert-description [&_a]:underline [&_a]:underline-offset-3 [&_a]:hover:text-foreground"
        ]
        content


{-| Renders alert action content.
-}
action : List (Html msg) -> Html msg
action content =
    div
        [ attribute "data-slot" "alert-action"
        , class "cn-alert-action"
        ]
        content


{-| Renders a configured alert.
-}
view : Config msg -> Html msg
view (Config configuration) =
    div
        ([ attribute "data-slot" "alert"
         , attribute "role" "alert"
         , class "cn-alert group/alert relative w-full"
         , class (variantClass configuration.variant)
         ]
            ++ configuration.attributes
        )
        configuration.content


{-| Returns the class for an alert appearance.
-}
variantClass : Variant -> String
variantClass variant =
    case variant of
        Default ->
            "cn-alert-variant-default"

        Destructive ->
            "cn-alert-variant-destructive"
