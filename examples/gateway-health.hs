{-# LANGUAGE OverloadedStrings #-}

-- OpenClaw Gateway Health Check (Haskell)
module Main where

import Network.HTTP.Simple (httpLBS, getResponseStatusCode, parseRequest)
import System.Environment (getArgs)

checkGateway :: String -> IO Int
checkGateway baseUrl = do
  request <- parseRequest (baseUrl ++ "/health")
  response <- httpLBS request
  return (getResponseStatusCode response)

main :: IO ()
main = do
  args <- getArgs
  let url = case args of
        (x : _) -> x
        _ -> "http://localhost:8080"
  status <- checkGateway url
  putStrLn $ "Gateway " ++ url ++ " -> HTTP " ++ show status
