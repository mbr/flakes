module ChadCn.Button exposing
    ( Config
    , NativeType(..)
    , Size(..)
    , Variant(..)
    , asInputGroupButton
    , new
    , view
    , withAttributes
    , withDisabled
    , withOnClick
    , withSize
    , withType
    , withVariant
    )

{-| Provides a reusable button component intended for extraction into a standalone package.
-}

import Html exposing (Attribute, Html)
import Html.Attributes exposing (attribute, class, disabled, type_)
import Html.Events exposing (onClick)


{-| Describes a button and its presentation.
-}
type Config msg
    = Config
        { attributes : List (Attribute msg)
        , content : List (Html msg)
        , disabled : Bool
        , nativeType : Maybe NativeType
        , onClick : Maybe msg
        , presentation : Presentation
        , size : Size
        , variant : Maybe Variant
        }


{-| Describes native button behavior.
-}
type NativeType
    = Button
    | Reset
    | Submit


{-| Describes button size.
-}
type Size
    = ExtraSmall
    | Small
    | Medium
    | Large
    | Icon
    | ExtraSmallIcon
    | SmallIcon
    | LargeIcon


{-| Describes button appearance.
-}
type Variant
    = Default
    | Destructive
    | Outline
    | Secondary
    | Ghost
    | Link


{-| Describes the context in which a button is rendered.
-}
type Presentation
    = Standalone
    | InputGroupButton


{-| Creates a default button with caller-owned content.
-}
new : List (Html msg) -> Config msg
new content =
    Config
        { attributes = []
        , content = content
        , disabled = False
        , nativeType = Nothing
        , onClick = Nothing
        , presentation = Standalone
        , size = Medium
        , variant = Nothing
        }


{-| Applies input-group button defaults.
-}
asInputGroupButton : Config msg -> Config msg
asInputGroupButton (Config configuration) =
    Config { configuration | presentation = InputGroupButton }


{-| Adds native attributes to the button.
-}
withAttributes : List (Attribute msg) -> Config msg -> Config msg
withAttributes attributes (Config configuration) =
    Config { configuration | attributes = configuration.attributes ++ attributes }


{-| Sets whether the button is disabled.
-}
withDisabled : Bool -> Config msg -> Config msg
withDisabled isDisabled (Config configuration) =
    Config { configuration | disabled = isDisabled }


{-| Sets the message emitted when the button is clicked.
-}
withOnClick : msg -> Config msg -> Config msg
withOnClick message (Config configuration) =
    Config { configuration | onClick = Just message }


{-| Sets the button size.
-}
withSize : Size -> Config msg -> Config msg
withSize size (Config configuration) =
    Config { configuration | size = size }


{-| Sets the native button behavior.
-}
withType : NativeType -> Config msg -> Config msg
withType nativeType (Config configuration) =
    Config { configuration | nativeType = Just nativeType }


{-| Sets the button appearance.
-}
withVariant : Variant -> Config msg -> Config msg
withVariant variant (Config configuration) =
    Config { configuration | variant = Just variant }


{-| Renders a configured button.
-}
view : Config msg -> Html msg
view (Config configuration) =
    Html.button
        ([ attribute "data-slot" "button"
         , class (baseClasses configuration.presentation)
         , class (variantClasses (configuredVariant configuration.presentation configuration.variant))
         , class (presentationSizeClasses configuration.presentation configuration.size)
         , disabled configuration.disabled
         ]
            ++ dataSizeAttributes configuration.presentation
            ++ nativeTypeAttributes configuration.nativeType
            ++ onClickAttributes configuration.onClick
            ++ configuration.attributes
        )
        configuration.content


{-| Returns attributes for an optional click message.
-}
onClickAttributes : Maybe msg -> List (Attribute msg)
onClickAttributes message =
    case message of
        Just clickMessage ->
            [ onClick clickMessage ]

        Nothing ->
            []


{-| Returns attributes for an optional native button type.
-}
nativeTypeAttributes : Maybe NativeType -> List (Attribute msg)
nativeTypeAttributes nativeType =
    case nativeType of
        Just configuredType ->
            [ type_ (nativeTypeName configuredType) ]

        Nothing ->
            [ type_ "button" ]


{-| Returns the HTML value for a native button type.
-}
nativeTypeName : NativeType -> String
nativeTypeName nativeType =
    case nativeType of
        Button ->
            "button"

        Reset ->
            "reset"

        Submit ->
            "submit"


{-| Returns base classes for the rendering context.
-}
baseClasses : Presentation -> String
baseClasses presentation =
    case presentation of
        Standalone ->
            "cn-button group/button inline-flex shrink-0 items-center justify-center whitespace-nowrap transition-all outline-none select-none disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0"

        InputGroupButton ->
            "cn-button group/button shrink-0 justify-center whitespace-nowrap transition-all outline-none select-none disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0"


{-| Returns data attributes for the rendering context.
-}
dataSizeAttributes : Presentation -> List (Attribute msg)
dataSizeAttributes presentation =
    case presentation of
        Standalone ->
            []

        InputGroupButton ->
            [ attribute "data-size" "xs" ]


{-| Returns classes for the rendering context.
-}
presentationSizeClasses : Presentation -> Size -> String
presentationSizeClasses presentation size =
    case presentation of
        Standalone ->
            sizeClasses size

        InputGroupButton ->
            "cn-button-size-default cn-input-group-button flex items-center shadow-none cn-input-group-button-size-xs"


{-| Returns classes for a button size.
-}
sizeClasses : Size -> String
sizeClasses size =
    case size of
        ExtraSmall ->
            "cn-button-size-xs"

        Small ->
            "cn-button-size-sm"

        Medium ->
            "cn-button-size-default"

        Large ->
            "cn-button-size-lg"

        Icon ->
            "cn-button-size-icon"

        ExtraSmallIcon ->
            "cn-button-size-icon-xs"

        SmallIcon ->
            "cn-button-size-icon-sm"

        LargeIcon ->
            "cn-button-size-icon-lg"


{-| Selects the configured or contextual button appearance.
-}
configuredVariant : Presentation -> Maybe Variant -> Variant
configuredVariant presentation variant =
    case variant of
        Just configured ->
            configured

        Nothing ->
            case presentation of
                Standalone ->
                    Default

                InputGroupButton ->
                    Ghost


{-| Returns classes for a button appearance.
-}
variantClasses : Variant -> String
variantClasses variant =
    case variant of
        Default ->
            "cn-button-variant-default"

        Destructive ->
            "cn-button-variant-destructive"

        Outline ->
            "cn-button-variant-outline"

        Secondary ->
            "cn-button-variant-secondary"

        Ghost ->
            "cn-button-variant-ghost"

        Link ->
            "cn-button-variant-link"
