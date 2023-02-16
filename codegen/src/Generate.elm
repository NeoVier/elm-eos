module Generate exposing (apiFiles)

{-| -}

import Abi
import Context
import Elm
import Generate.Action
import Generate.Action.Metadata
import Generate.Table
import Generate.Table.Decoder
import Generate.Table.Metadata
import Generate.Table.Query
import String.Extra


apiFiles : List String -> List { abi : Abi.Abi, baseUrl : String, contract : String } -> List Elm.File
apiFiles base abis =
    List.concatMap
        (\{ abi, baseUrl, contract } ->
            apiFilesFromAbi base
                { baseUrl = baseUrl, contract = contract }
                abi
        )
        abis


apiFilesFromAbi : List String -> Context.Context -> Abi.Abi -> List Elm.File
apiFilesFromAbi base context abi =
    let
        fileName : List String -> List String
        fileName suffix =
            base ++ Context.prefixed context suffix

        prefixedFile :
            List String
            -> { docs : List { group : Maybe String, members : List String } -> List String }
            -> List Elm.Declaration
            -> Elm.File
        prefixedFile suffix { docs } =
            Elm.fileWith (fileName suffix)
                { aliases = []
                , docs = \groupsAndMembers -> autoGeneratedWarning :: docs groupsAndMembers
                }

        autoGeneratedWarning : String
        autoGeneratedWarning =
            "This file was automatically generated by henriquecbuss/elm-eos. Do not edit it by hand!"

        makeDocs : List { group : Maybe String, members : List String } -> List String
        makeDocs groupsAndMembers =
            List.map (\group -> Elm.docs { group | members = List.reverse group.members })
                groupsAndMembers
    in
    [ prefixedFile [ "Action" ]
        { docs =
            \groupsAndMembers ->
                ("This file contains all of the actions for the "
                    ++ context.contract
                    ++ " contract. In order to send an action to the blockchain, create an [Action](#Action), [encode](#encode) it, and send through a port to eosjs, or similar."
                )
                    :: makeDocs groupsAndMembers
        }
        [ Generate.Action.type_ abi.actions
            |> Elm.exposeWith { exposeConstructor = True, group = Just "Action" }
        , Generate.Action.encode context
            |> Elm.exposeWith { exposeConstructor = True, group = Just "Encoding" }
        , Generate.Action.encodeSingleAction abi.actions
            |> Elm.exposeWith { exposeConstructor = True, group = Just "Encoding" }
        , Generate.Action.getName abi.actions
        ]
    , prefixedFile [ "Action", "Metadata" ]
        { docs =
            \groupsAndMembers ->
                ("This file contains metadata about actions from the "
                    ++ context.contract
                    ++ " contract. You should only need this if you're building something like a contract explorer or an auto generated app."
                )
                    :: makeDocs groupsAndMembers
        }
        [ Generate.Action.Metadata.allMetadata abi.actions
            |> Elm.exposeWith { exposeConstructor = True, group = Just "Metadata" }
        ]
    , prefixedFile [ "Table" ]
        { docs =
            \groupsAndMembers ->
                ("This file contains Elm types that represent all of the tables for the "
                    ++ context.contract
                    ++ " contract. You can query them with functions from the "
                    ++ (fileName [ "Table", "Query" ]
                            |> List.map String.Extra.classify
                            |> String.join "."
                       )
                    ++ " module, and perform the queries with [Eos.Query.send](Eos-Query#send)"
                )
                    :: makeDocs groupsAndMembers
        }
        (List.map
            (Generate.Table.type_
                >> Elm.exposeWith
                    { exposeConstructor = False
                    , group = Just "Tables"
                    }
            )
            abi.tables
        )
    , prefixedFile [ "Table", "Metadata" ]
        { docs =
            \groupsAndMembers ->
                ("This file contains metadata about tables from the "
                    ++ context.contract
                    ++ " contract. You should only need this if you're building something like a contract explorer or an auto generated app"
                )
                    :: makeDocs groupsAndMembers
        }
        [ Generate.Table.Metadata.typeUnion (fileName []) abi.tables
            |> Elm.exposeWith { exposeConstructor = True, group = Just "Metadata" }
        , Generate.Table.Metadata.allMetadata (fileName []) abi.tables
            |> Elm.exposeWith { exposeConstructor = True, group = Just "Metadata" }
        ]
    , prefixedFile [ "Table", "Decoder" ]
        { docs =
            \groupsAndMembers ->
                ("This file contains functions that decode the results of queries to the blockchain into types from "
                    ++ (fileName [ "Table" ]
                            |> List.map String.Extra.classify
                            |> String.join "."
                       )
                    ++ ". You probably won't need these! Just use [Eos.Query](Eos-Query), which will automatically decode things for you."
                )
                    :: makeDocs groupsAndMembers
        }
        (Generate.Table.Decoder.generateIntDecoder
            :: List.map
                (Generate.Table.Decoder.generate context
                    >> Elm.exposeWith
                        { exposeConstructor = True
                        , group = Just "Decoders"
                        }
                )
                abi.tables
        )
    , prefixedFile [ "Table", "Query" ]
        { docs =
            \groupsAndMembers ->
                "This is the file you want to use to query the blockchain for data, along with [Eos.Query.send](Eos-Query#send)."
                    :: makeDocs groupsAndMembers
        }
        (List.map
            (Generate.Table.Query.generateQuery context
                >> Elm.exposeWith
                    { exposeConstructor = True
                    , group = Just "Queries"
                    }
            )
            abi.tables
        )
    ]
