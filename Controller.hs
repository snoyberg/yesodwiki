{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module Controller
    ( withWiki
    , withDevelApp
    ) where

import Wiki
import Settings
import Yesod.Static
import Yesod.Auth
import Database.Persist.GenericSql
import Data.ByteString (ByteString)
import Data.Dynamic (Dynamic, toDyn)
import Network.Wai (Application)

-- Import all relevant handler modules here.
import Handler.Topic
import Handler.CreateTopic
import Handler.CreateMap
import Handler.ShowMap
import Handler.EditMap
import Handler.Feed
import Handler.Settings
import Handler.Root
import Handler.Labels
import Handler.Browse
import Handler.Blog
import Handler.Book
import Handler.Search
import Handler.UploadDitamap
import Handler.DownloadDitamap
import Handler.UploadBlogs
import Handler.Wiki

-- This line actually creates our YesodSite instance. It is the second half
-- of the call to mkYesodData which occurs in Wiki.hs. Please see
-- the comments there for more details.
mkYesodDispatch "Wiki" resourcesWiki

-- Some default handlers that ship with the Yesod site template. You will
-- very rarely need to modify this.
getFaviconR :: Handler ()
getFaviconR = sendFile "image/x-icon" "config/favicon.ico"

getRobotsR :: Handler RepPlain
getRobotsR = return $ RepPlain $ toContent ("User-agent: *" :: ByteString)

-- This function allocates resources (such as a database connection pool),
-- performs initialization and creates a WAI application. This is also the
-- place to put your migrate statements to have automatic database
-- migrations handled by Yesod.
withWiki :: Text -> (Application -> IO a) -> IO a
withWiki approot' f = Settings.withConnectionPool $ \p -> do
    runConnectionPool (runMigration migrateAll) p
    s <- static Settings.staticdir
    let h = Wiki s p approot'
    toWaiApp h >>= f

withDevelApp :: Dynamic
withDevelApp = toDyn (withWiki "http://10.0.0.3:3000" :: (Application -> IO ()) -> IO ())
