{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# OPTIONS_GHC -Wno-missing-signatures #-}
{-# OPTIONS_GHC -Wno-missing-methods #-}

module Types where

import           AutoApply
import           Control.Monad.IO.Class
import           Data.Kind

----------------------------------------------------------------
-- Values to test with
----------------------------------------------------------------

newtype Resource a = Resource a

myBracket
  :: MyConstraint m
  => MyMonadT m a
  -> (a -> MyMonadT m c)
  -> (a -> MyMonadT m b)
  -> MyMonadT m b
myBracket = undefined

class MonadResource (m :: Type -> Type) where
data ReleaseKey
myAllocate :: MonadResource m => IO a -> (a -> IO ()) -> m (ReleaseKey, a)
myAllocate = undefined

data Baz
data Qux

class Monad m => MyConstraint (m :: Type -> Type) where

newtype MyMonadT a b = MyMonadT (a b)
  deriving newtype (Functor, Applicative, Monad)

getBazSem :: MyConstraint m => MyMonadT m Baz
getBazSem = undefined

getQux :: m Qux
getQux = undefined

getQuxIO :: IO Qux
getQuxIO = undefined

aQux :: Qux
aQux = undefined

-- $setup
-- >>> :set -XTemplateHaskell
-- >>> import Control.Exception

----------------------------------------------------------------
-- Tests
----------------------------------------------------------------

-- | Two monadic bindings
--
-- >>> x = $(autoapply ['getBazSem, 'getQux] 'test1)
-- >>> :t x
-- x :: MyConstraint m => MyMonadT m ()
test1 :: Baz -> Qux -> m ()
test1 = undefined

-- | 'aQux' is substituted and 'Baz' is left as an argument
--
-- >>> x = $(autoapply ['aQux] 'test2)
-- >>> :t x
-- x :: Baz -> m ()
test2 :: Baz -> Qux -> m ()
test2 = undefined

-- | 'id' gets substituted at @(a -> a)@
--
-- >>> $(autoapply ['id] 'test3)
-- ()
test3 :: (a -> a) -> ()
test3 = const ()

-- | 'id' gets substituted at @(a -> b)@
--
-- >>> $(autoapply ['id] 'test4)
-- ()
test4 :: (a -> b) -> ()
test4 = const ()

-- | @aQux :: Qux@ gets substituted at @a@

-- >>> $(autoapply ['aQux] 'test5)
-- ()
test5 :: a -> ()
test5 = const ()

-- | 'id' does not get substituted at @(forall a b. a -> b)@
--
-- >>> x = $(autoapply ['id] 'test6)
-- >>> :t x
-- x :: (forall a b. a -> b) -> ()
--
-- 'undefined' does
-- >>> x = $(autoapply ['undefined] 'test6)
-- >>> :t x
-- x :: ()
test6 :: (forall a b. a -> b) -> ()
test6 = const ()
autoapplyDecs (<> "'") ['id] ['test6]
test6' :: (forall a b. a -> b) -> ()

-- | @aQux :: Qux@ does not get substituted at @forall a. a@
--
-- >>> x = $(autoapply ['aQux] 'test7)
-- >>> :t x
-- x :: (forall a. a) -> ()
test7 :: (forall a. a) -> ()
test7 = const ()

-- | 'id' is instantiated twice at different types
-- >>> $(autoapply ['id] 'test8)
-- ()
test8 :: (Baz -> Baz) -> (Qux -> Qux) -> ()
test8 = const (const ())

-- | The return type changes
--
-- >>> x = $(autoapply ['reverse] 'test9)
-- >>> :t x
-- x :: [a] -> [a]
test9 :: ([a] -> b) -> [a] -> b
test9 = test9

-- | Two monadic bindings with types incompatible with one another
--
-- >>> x = $(autoapply ['getBazSem, 'getQuxIO] 'test10)
-- >>> :t x
-- x :: MyConstraint m => Qux -> MyMonadT m ()
--
-- Responds to the order of types in the applying function, not the order types
-- of values to be passed.
-- >>> x = $(autoapply ['getQuxIO, 'getBazSem] 'test10)
-- >>> :t x
-- x :: MyConstraint m => Qux -> MyMonadT m ()
test10 :: Baz -> Qux -> m ()
test10 = undefined

-- | Monadic binding with incompatible type
--
-- >>> x = $(autoapply ['getBazSem, 'getQuxIO] 'test11)
-- >>> :t x
-- x :: Baz -> IO ()
test11 :: Baz -> Qux -> IO ()
test11 = undefined

-- | Several instantiations of the same function
--
-- >>> x = $(autoapply ['bracket, 'getBazSem, 'aQux] 'test12)
-- >>> :t x
-- x :: Baz -> (a -> IO c) -> IO c
--
-- >>> x = $(autoapply ['myBracket, 'aQux] 'test12)
-- >>> :t x
-- x :: MyConstraint m => Baz -> (a -> MyMonadT m b) -> MyMonadT m b
--
-- >>> x = $(autoapply ['myAllocate, 'aQux] 'test12)
-- >>> :t x
-- x :: MonadResource m => Baz -> m (ReleaseKey, a)
test12 :: (m a -> (a -> m b) -> c) -> Baz -> Qux -> c
test12 = undefined

-- |
--
-- >>> x = $(autoapply ['exitFailure] 'liftIO)
-- >>> :t x
-- x :: MonadIO m => m a
exitFailure :: IO a
exitFailure = undefined

----------------------------------------------------------------
-- Examples from readme
----------------------------------------------------------------


class Member a (r :: [Type]) where
data Sem (r :: [Type]) a
instance Functor (Sem r)
instance Applicative (Sem r)
instance Monad (Sem r)
data Input a
input :: Member (Input a) r => Sem r a
input = undefined

data Instance
data ExtraOpenInfo
data Foo
data Bar
data Handle
openHandle :: MonadIO m => Instance -> Maybe ExtraOpenInfo -> m Handle
openHandle = undefined
closeHandle :: MonadIO m => Instance -> Handle -> m ()
closeHandle = undefined
useHandle :: MonadIO m => Instance -> Handle -> Foo -> m Bar
useHandle = undefined

myExtraOpenInfo :: Maybe ExtraOpenInfo
myExtraOpenInfo = Nothing
getInstance :: Member (Input Instance) r => Sem r Instance
getInstance = input

autoapplyDecs (<> "'") ['myExtraOpenInfo, 'getInstance] ['openHandle, 'closeHandle, 'useHandle]