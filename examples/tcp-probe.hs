-- OpenClaw TCP port probe (Haskell) — checks gateway nodes (network package)
module Main where

import Control.Exception (SomeException, try)
import Network.Socket

probe :: String -> String -> IO Bool
probe host port = do
  result <- try $ do
    addr : _ <-
      getAddrInfo (Just defaultHints {addrSocketType = Stream}) (Just host) (Just port)
    sock <- socket (addrFamily addr) (addrSocketType addr) (addrProtocol addr)
    connect sock (addrAddress addr)
    close sock
  case (result :: Either SomeException ()) of
    Right _ -> return True
    Left _ -> return False

main :: IO ()
main = do
  let nodes = [("localhost", "8080"), ("localhost", "8081")]
  mapM_
    ( \(h, p) -> do
        ok <- probe h p
        putStrLn $ (if ok then "OK  " else "FAIL") ++ " " ++ h ++ ":" ++ p
    )
    nodes
