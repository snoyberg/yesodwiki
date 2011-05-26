{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE OverloadedStrings #-}
module Util
    ( renderContent
    , validateContent
    , userGravatar
    , prettyDate
    , prettyMonthYear
    ) where

import Model (TopicFormat (..), User (userEmail))
import Data.Text (Text, pack, unpack)
import Data.Text.Encoding (encodeUtf8)
import Text.Hamlet (Html, preEscapedText, toHtml, preEscapedString)
import Text.HTML.SanitizeXSS (sanitizeBalance)
import Text.Hamlet.NonPoly (html)
import Data.Digest.Pure.MD5 (md5)
import Data.Char (isSpace, toLower)
import Data.Maybe (fromMaybe)
import qualified Data.ByteString.Lazy as L
import Text.Pandoc (writeHtmlString, defaultWriterOptions, readMarkdown, defaultParserState)
import qualified Data.Text as T
import Yesod.Form (Textarea (Textarea))
import System.Locale
import Data.Time (formatTime, UTCTime, fromGregorian)
import Text.XML.Enumerator.Parse (parseText, decodeEntities)
import Text.XML.Enumerator.Document (fromEvents)
import Data.Enumerator (run, ($$), joinI, enumList)
import Data.Functor.Identity (runIdentity)
import Data.XML.Types (Node (..), Content (..), Document (..), Element (..))
import Wiki (WikiRoute (..), fromSinglePiece)
import Data.Maybe (fromJust)
import Text.Hamlet (Hamlet)

renderContent :: TopicFormat -> Text -> Hamlet WikiRoute
renderContent TFHtml t = const $ preEscapedText t
renderContent TFText t = const $ toHtml $ Textarea t
renderContent TFMarkdown t = const $ preEscapedString $ writeHtmlString defaultWriterOptions $ readMarkdown defaultParserState $ unpack t
renderContent TFDitaConcept t = ditaToHtml t
renderContent TFDitaTopic t = ditaToHtml t

ditaToHtml :: Text -> Hamlet WikiRoute
ditaToHtml txml render =
    case runIdentity $ run $ enumList 3 ["<body>", txml, "</body>"] $$ joinI $ parseText decodeEntities $$ fromEvents of
        Left e -> toHtml $ show e
        Right (Document _ (Element _ _ nodes) _) -> mapM_ go nodes
  where
    go (NodeContent (ContentText t')) = toHtml t'
    go (NodeElement (Element n as children)) = go' n as $ mapM_ go children
    go _ = return ()
    go' "p" _ x = [html|<p>#{x}|]
    go' "ul" _ x = [html|<ul>#{x}|]
    go' "ol" _ x = [html|<ol>#{x}|]
    go' "li" _ x = [html|<li>#{x}|]
    go' "i" _ x = [html|<i>#{x}|]
    go' "b" _ x = [html|<b>#{x}|]
    go' "fig" _ x = [html|<fieldset>#{x}|]
    go' "title" _ x = [html|<legend>#{x}|]
    go' "image" as x =
        case lookup "href" as of
            Just [ContentText t] -> [html|<img src=#{toLink t}>#{show as}, #{x}|]
            _ -> x
    go' "xref" as x =
        case lookup "href" as of
            Just [ContentText t] -> [html|<a href=#{toLink t}>#{x}|]
            _ -> x
    go' "codeph" _ x = [html|<code>#{x}|]
    go' "term" _ x = [html|<b>#{x}|]
    go' "dl" _ x = [html|<dl>#{x}|]
    go' "dlentry" _ x = [html|#{x}|]
    go' "dt" _ x = [html|<dt>#{x}|]
    go' "dd" _ x = [html|<dd>#{x}|]
    go' "apiname" _ x = [html|<a href="http://hackage.haskell.org/package/#{x}">#{x}|]
    go' "codeblock" _ x = [html|<pre>
    <code>#{x}|]
    go' "note" as x =
        case lookup "type" as of
            Just [ContentText nt]
                | nt == "other" ->
                    case lookup "othertype" as of
                        Just [ContentText ot] -> [html|<.note-#{ot}>#{x}|]
                        _ -> [html|<.note#{x}>|]
                | otherwise -> [html|<.#{nt}>#{x}|]
            _ -> [html|<.note>#{x}|]
    go' n _ _ = [html|<h1 style=color:red>Unknown DITA element: #{show n}|]
    toLink t
        | topicPref `T.isPrefixOf` t =
            let suffix = T.drop (T.length topicPref) t
                (tid, rest) = T.break (== '#') suffix
             in render (TopicR $ fromJust $ fromSinglePiece tid) [] `T.append` rest
        | staticPref `T.isPrefixOf` t = render (StaticContentR $ fromJust $ fromSinglePiece $ T.drop (T.length staticPref) t) []
        | "yw://" `T.isPrefixOf` t = "FIXME: " `T.append` t
        | otherwise = t
    topicPref = "yw://topic/"
    staticPref = "yw://static/"

validateContent :: TopicFormat -> Text -> Text
validateContent TFHtml t = pack $ sanitizeBalance $ unpack t
validateContent TFText t = t
validateContent TFMarkdown t = T.filter (/= '\r') t
validateContent tf _ = pack $ "validateContent: not yet written for " ++ show tf

userGravatar :: User -> Html
userGravatar u =
    [html|<img src="http://www.gravatar.com/avatar/#{hash}?d=identicon&s=100">|]
  where
    email = fromMaybe "" $ userEmail u
    hash = pack $ show $ md5 $ L.fromChunks $ return $ encodeUtf8 $ pack $ map toLower $ trim $ unpack email
    trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

prettyDate :: UTCTime -> String
prettyDate = formatTime defaultTimeLocale "%B %e, %Y" -- FIXME i18n

prettyMonthYear :: Int -> Int -> String
prettyMonthYear year month = formatTime defaultTimeLocale "%B %Y" $ fromGregorian (fromIntegral year) month 1 -- FIXME i18n
