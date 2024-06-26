-- | A search engine that is used in the browser.
module Docs.Search.BrowserEngine where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Array as Array
import Data.Codec.JSON as CJ
import Data.Codec.JSON.Common as CJ.Common
import Data.Either (hush)
import Data.List (List)
import Data.List as List
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype)
import Data.Search.Trie (Trie)
import Data.Search.Trie as Trie
import Data.String.CodeUnits as String
import Data.Tuple (Tuple(..))
import Docs.Search.Config as Config
import Docs.Search.Engine (Engine, EngineState, Index)
import Docs.Search.ModuleIndex as ModuleIndex
import Docs.Search.PackageIndex as PackageIndex
import Docs.Search.SearchResult (SearchResult)
import Docs.Search.SearchResult as SearchResult
import Docs.Search.TypeIndex (TypeIndex)
import Docs.Search.TypeIndex as TypeIndex
import Docs.Search.Types (PartId, URL)
import Effect (Effect)
import Effect.Aff (Aff, try)
import JSON (JSON)

newtype PartialIndex = PartialIndex (Map PartId Index)

derive instance newtypePartialIndex :: Newtype PartialIndex _

type BrowserEngineState = EngineState PartialIndex TypeIndex

-- | This function dynamically injects a script with the required index part and returns
-- | a new `PartialIndex` that contains newly loaded definitions.
-- |
-- | We split the index because of its size, and also to speed up queries.
query
  :: PartialIndex
  -> String
  -> Aff { index :: PartialIndex, results :: Array SearchResult }
query index@(PartialIndex indexMap) input = do
  let
    path =
      List.fromFoldable
        $ String.toCharArray
        $
          input

    partId = Config.getPartId path

  case Map.lookup partId indexMap of
    Just trie ->
      pure { index, results: flatten $ Trie.queryValues path trie }
    Nothing -> do

      eiPartJson <-
        try $ toAffE $ loadIndex_ partId $ Config.mkIndexPartLoadPath partId

      let
        resultsCodec :: CJ.Codec (Array (Tuple String (Array SearchResult)))
        resultsCodec = CJ.array $ CJ.Common.tuple CJ.string $ CJ.array SearchResult.searchResultCodec

        mbNewTrie :: Maybe (Trie Char (List SearchResult))
        mbNewTrie = do
          json <- hush eiPartJson
          results <- hush $ CJ.decode resultsCodec json
          pure $ Array.foldr insertResults mempty results

      case mbNewTrie of
        Just newTrie -> do
          pure
            { index: PartialIndex $ Map.insert partId newTrie indexMap
            , results: flatten $ Trie.queryValues path newTrie
            }
        Nothing -> do
          pure { index, results: mempty }

  where
  flatten = Array.concat <<< Array.fromFoldable <<< map Array.fromFoldable

insertResults
  :: Tuple String (Array SearchResult)
  -> Trie Char (List SearchResult)
  -> Trie Char (List SearchResult)
insertResults (Tuple path newResults) =
  Trie.alter pathList insert
  where
  pathList = List.fromFoldable $ String.toCharArray path

  insert
    :: Maybe (List SearchResult)
    -> Maybe (List SearchResult)
  insert mbOldResults =
    case mbOldResults of
      Nothing -> Just $ List.fromFoldable newResults
      Just old -> Just $ List.fromFoldable newResults <> old

browserSearchEngine
  :: Engine Aff PartialIndex TypeIndex
browserSearchEngine =
  { queryIndex: query
  , queryTypeIndex: TypeIndex.query
  , queryPackageIndex: PackageIndex.queryPackageIndex
  , queryModuleIndex: ModuleIndex.queryModuleIndex
  }

-- | Load a part of the index by injecting a <script> tag into the DOM.
foreign import loadIndex_
  :: PartId
  -> URL
  -> Effect (Promise JSON)
