module GatewayClient exposing (main)

-- OpenClaw Gateway Client (Elm)

import Browser
import Html exposing (Html, text)
import Http


type Model
    = Loading
    | Healthy Int
    | Failed


type Msg
    = GotHealth (Result Http.Error ())


gatewayUrl : String
gatewayUrl =
    "http://localhost:8080"


checkHealth : Cmd Msg
checkHealth =
    Http.get
        { url = gatewayUrl ++ "/health"
        , expect = Http.expectWhatever GotHealth
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, checkHealth )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg _ =
    case msg of
        GotHealth (Ok _) ->
            ( Healthy 200, Cmd.none )

        GotHealth (Err _) ->
            ( Failed, Cmd.none )


view : Model -> Html Msg
view model =
    case model of
        Loading ->
            text "checking gateway..."

        Healthy code ->
            text ("Gateway OK -> HTTP " ++ String.fromInt code)

        Failed ->
            text "Gateway FAIL"


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }
