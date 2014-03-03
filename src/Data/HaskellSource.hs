-- | A representation of Haskell source code.
-- 
-- Unlike haskell-src-exts, our goal is not to reconstruct detailed semantics,
-- but to preserve original line numbers (if applicable).
module Data.HaskellSource where

import Data.ByteString.Char8 as B
import Text.Printf


-- | The ByteStrings are original lines, which we never delete in order to
--   infer line numbers, while the Strings were inserted into the original.
type HaskellSource = [Either B.ByteString String]


parseSource :: B.ByteString -> HaskellSource
parseSource = fmap Left . B.lines

-- | A string representation containing line pragmas so that compiler errors
--   are reported about the original file instead of the modified one.
-- 
-- >>> let (x:xs) = parseSource $ B.pack "import Data.ByteString\nmain = print 42\n"
-- >>> B.putStr $ printSource "orig.hs" (x:xs)
-- import Data.ByteString
-- main = print 42
-- 
-- >>> B.putStr $ printSource "orig.hs" (x:Right "import Prelude":xs)
-- import Data.ByteString
-- import Prelude
-- {-# LINE 2 "orig.hs" #-}
-- main = print 42
printSource :: FilePath -- ^ the original's filename,
                        --   used for fixing up line numbers
            -> HaskellSource -> B.ByteString
printSource orig = B.unlines . go True 1
  where
    go :: Bool -- ^ are line numbers already ok?
       -> Int  -- ^ the original number of the next original line
       -> HaskellSource
       -> [B.ByteString]
    go _     _ []           = []
    go True  i (Left x:xs)  = x
                            : go True (i + 1) xs
    go False i (Left x:xs)  = B.pack (line_marker i)
                            : x
                            : go True (i + 1) xs
    go _     i (Right x:xs) = B.pack x
                            : go False i xs
    
    line_marker :: Int -> String
    line_marker i = printf "{-# LINE %s %s #-}" (show i) (show orig)


readSource :: FilePath -> IO HaskellSource
readSource = fmap parseSource . B.readFile

writeSource :: FilePath -- ^ the original's filename,
                        --   used for fixing up line numbers
            -> FilePath
            -> HaskellSource
            -> IO ()
writeSource orig f = B.writeFile f . printSource orig