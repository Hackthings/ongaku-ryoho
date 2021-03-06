module Sources.Processing
    exposing
        ( takeFirstStep
        , takeTreeStep
        , takeTagsStep
          --
        , findTagsContextSource
        , tracksFromTagsContext
        )

{-| Processing.

    ## How it works

    This describes the process for a single source.

    1. Get a file tree/list from the source
       -> This can happen in multiple steps as with Amazon S3.
          A command is issued for each step of this process.
    2. Get the tags (ie. metadata) for each file that we found.
       -> This also happens in multiple steps, so that we can flush
          every x tracks while processing.
          A command is issued for each step of this process.

-}

import Date exposing (Date)
import List.Extra as List exposing (remove)
import Maybe.Extra as Maybe
import Response.Ext exposing (do)
import Sources.Ports as Ports
import Sources.Services as Services
import Sources.Types exposing (..)
import Tracks.Types exposing (TagUrls, Track, makeTrack)


-- Settings


{-| How much tags do we want to process
before we send them back to Elm.

    eg. After we got the tags for 50 tracks,
    we store these and continue with the rest.

-}
tagsBatchSize : Int
tagsBatchSize =
    50



-- {public} 1st step


takeFirstStep : Date -> Source -> Cmd Msg
takeFirstStep currentDate source =
    let
        initialContext =
            { filePaths = []
            , source = source
            , treeMarker = TheBeginning
            }
    in
        makeTree initialContext currentDate



-- {public} 2nd step


takeTreeStep : ProcessingContext -> String -> List Track -> Date -> Cmd Msg
takeTreeStep context response associatedTracks currentDate =
    context
        |> handleTreeResponse response
        |> intoTreeCommand associatedTracks currentDate



-- {public} 3rd step


takeTagsStep : Date -> ProcessingContextForTags -> Source -> Maybe (Cmd Msg)
takeTagsStep currentDate tagsCtx source =
    let
        ( filesToProcess, nextFiles ) =
            List.splitAt tagsBatchSize tagsCtx.nextFilePaths

        newTagsCtx =
            { nextFilePaths = nextFiles
            , receivedFilePaths = filesToProcess
            , receivedTags = []
            , sourceId = source.id
            , urlsForTags = makeTrackUrls currentDate source filesToProcess
            }
    in
        filesToProcess
            |> List.head
            |> Maybe.map (always (Ports.requestTags newTagsCtx))



-- Tree


handleTreeResponse : String -> ProcessingContext -> ProcessingContext
handleTreeResponse response context =
    let
        parsingFunc =
            Services.parseTreeResponse context.source.service

        parsedResponse =
            parsingFunc response context.treeMarker
    in
        { context
            | filePaths = context.filePaths ++ parsedResponse.filePaths
            , treeMarker = parsedResponse.marker
        }


intoTreeCommand : List Track -> Date -> ProcessingContext -> Cmd Msg
intoTreeCommand associatedTracks currentDate context =
    case context.treeMarker of
        TheBeginning ->
            Cmd.none

        -- Still busy building the tree,
        -- carry on.
        --
        InProgress _ ->
            makeTree context currentDate

        -- The tree's been build,
        -- let's continue to the next step.
        --
        TheEnd ->
            let
                filteredFiles =
                    Services.postProcessTree context.source.service context.filePaths

                postContext =
                    { context | filePaths = filteredFiles }

                ( pathsAlreadyExist, pathsToRemove, _ ) =
                    separateTree postContext associatedTracks
            in
                Cmd.batch
                    [ -- Get tags from tracks
                      postContext
                        |> selectNonExisting pathsAlreadyExist
                        |> processingContextToTagsContext
                        |> ProcessTagsStep
                        |> do

                    -- Remove tracks
                    , pathsToRemove
                        |> ProcessTreeStepRemoveTracks context.source.id
                        |> do
                    ]


makeTree : ProcessingContext -> CmdWithTimestamp
makeTree context =
    Services.makeTree
        context.source.service
        context.source.data
        context.treeMarker
        (ProcessTreeStep context)


separateTree : ProcessingContext -> List Track -> ( List String, List String, List String )
separateTree context tracks =
    List.foldr
        (\track ( left, toRemove, srcOfTruth ) ->
            let
                path =
                    track.path
            in
                if List.member path srcOfTruth then
                    ( path :: left, toRemove, remove path srcOfTruth )
                else
                    ( left, path :: toRemove, srcOfTruth )
        )
        ( [], [], context.filePaths )
        tracks


selectNonExisting : List String -> ProcessingContext -> ProcessingContext
selectNonExisting existingPaths context =
    let
        notMember =
            flip List.notMember
    in
        { context
            | filePaths = List.filter (notMember existingPaths) context.filePaths
        }



-- Tags


makeTrackUrls : Date -> Source -> List String -> List TagUrls
makeTrackUrls currentDate source filePaths =
    let
        maker =
            Services.makeTrackUrl source.service

        mapFn =
            \path ->
                { getUrl = maker currentDate source.data Get path
                , headUrl = maker currentDate source.data Head path
                }
    in
        List.map mapFn filePaths



-- {public} Utils


findTagsContextSource : ProcessingContextForTags -> List Source -> Maybe Source
findTagsContextSource tagsContext =
    List.find (.id >> (==) tagsContext.sourceId)


tracksFromTagsContext : ProcessingContextForTags -> List Track
tracksFromTagsContext context =
    context.receivedTags
        |> List.zip context.receivedFilePaths
        |> List.filter (Tuple.second >> Maybe.isJust)
        |> List.map (Tuple.mapSecond (Maybe.withDefault Tracks.Types.emptyTags))
        |> List.map (makeTrack context.sourceId)



-- {private} Utils


processingContextToTagsContext : ProcessingContext -> ProcessingContextForTags
processingContextToTagsContext context =
    { nextFilePaths = context.filePaths
    , receivedFilePaths = []
    , receivedTags = []
    , sourceId = context.source.id
    , urlsForTags = []
    }
