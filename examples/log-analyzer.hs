-- OpenClaw log analyzer (Haskell) — parses gateway access logs from stdin
module Main where

import qualified Data.Map.Strict as Map

tally :: String -> Map.Map String Int -> Map.Map String Int
tally line acc =
  case words line of
    (_ : level : _) | level `elem` ["INFO", "WARN", "ERROR"] ->
      Map.insertWith (+) level 1 acc
    _ -> acc

main :: IO ()
main = do
  contents <- getContents
  let ls = lines contents
  mapM_ putStrLn
    [ "\9888 " ++ ts ++ " [" ++ node ++ "] " ++ unwords msg
    | l <- ls
    , (ts : "ERROR" : node : msg) <- [words l]
    ]
  putStrLn "\n--- Summary ---"
  mapM_ (\(k, v) -> putStrLn (k ++ ": " ++ show v))
    (Map.toList (foldr tally Map.empty ls))
