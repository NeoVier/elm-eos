module Context exposing (Context, decoder, prefixed)

import Json.Decode
import String.Extra


type alias Context =
    { baseUrl : String
    , contract : String
    }


decoder : Json.Decode.Decoder Context
decoder =
    Json.Decode.map2
        (\baseUrl contract -> { baseUrl = baseUrl, contract = contract })
        (Json.Decode.field "baseUrl" Json.Decode.string)
        (Json.Decode.field "contract" Json.Decode.string)


prefixed : Context -> List String -> List String
prefixed context suffix =
    (String.split "." context.contract ++ suffix)
        |> List.map String.Extra.classify
