module Test.Util where

import Prelude hiding (absurd)

import App.Fig (LinkFigSpec, linkResult, loadLinkFig)
import App.Util (Selector)
import Data.Either (Either(..))
import Data.List (elem)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Tuple (fst, snd)
import DataType (dataTypeFor, typeName)
import Debug (trace)
import Desugarable (desugFwd', desugBwd')
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Class.Console (log)
import Effect.Console (logShow)
import Eval (eval)
import EvalBwd (evalBwd)
import Lattice (𝔹, bot, erase)
import Module (File(..), Folder(..), loadFile, open, openDatasetAs, openWithDefaultImports, parse)
import Parse (program)
import Pretty (class Pretty, prettyP)
import Pretty2 (pretty)
import SExpr (Expr) as S
import Test.Spec (SpecT, before, it)
import Test.Spec.Assertions (fail, shouldEqual)
import Test.Spec.Mocha (runMocha)
import Util (type (×), (×), successful)
import Util.Pretty (render)
import Val (Env, Val(..), (<+>))

-- Don't enforce expected values for graphics tests (values too complex).
isGraphical :: forall a. Val a -> Boolean
isGraphical (Constr _ c _) = typeName (successful (dataTypeFor c)) `elem` [ "GraphicsElement", "Plot" ]
isGraphical _ = false

type Test a = SpecT Aff Unit Effect a

run :: forall a. Test a → Effect Unit
run = runMocha -- no reason at all to see the word "Mocha"

checkPretty :: forall a. Pretty a => String -> String -> a -> Aff Unit
checkPretty _ expected x =
   -- trace (msg <> ":\n" <> prettyP x) \_ ->
   prettyP x `shouldEqual` expected



-- testWithSetup :: Boolean -> File -> String -> Maybe (Selector × File) -> Aff (Env 𝔹 × S.Expr 𝔹) -> Test Unit
-- testWithSetup (bol) (File file) expected v_expect_opt setup =
--    before setup $
--       it file \(γ × s) -> do
--          let
--             e = successful (desugFwd' s)
--             t × v = successful (eval γ e bot)
--             v' = fromMaybe identity (fst <$> v_expect_opt) v
--             { γ: γ', e: e' } = evalBwd (erase <$> γ) (erase e) v' t
--             s' = desugBwd' e' :: S.Expr _
--             _ × v'' = successful (eval γ' (successful (desugFwd' s')) true)
--             src = render (pretty s)
--             srcExp = show (erase s)
--          trace ("1:\n" <> src) \_ -> do
--             liftEffect (log ("SRC\n" <> srcExp))
--             case parse src program of
--                Left msg -> fail msg
--                Right newProg -> do
--                   let newExp = show newProg
--                   --liftEffect (log ("SRC\n" <> srcExp))
--                   liftEffect (log ("NEW\n" <> newExp))
--                   liftEffect (logShow (eq (erase s) newProg))
--                   unless (isGraphical v'') (checkPretty "Value" expected v'')
--                   trace ("\n" <> src) \_ -> do
--                      unless (isGraphical v'') (checkPretty "Value" expected v'')
--                      case snd <$> v_expect_opt of
--                         Nothing -> pure unit
--                         Just file_expect ->
--                            loadFile (Folder "fluid/example") file_expect >>= flip (checkPretty "Source selection") s'

testWithSetup :: Boolean -> File -> String -> Maybe (Selector × File) -> Aff (Env 𝔹 × S.Expr 𝔹) -> Test Unit
testWithSetup (bol) (File file) expected v_expect_opt setup =
   before setup $
      it file \(γ × s) -> do
         let
            e = successful (desugFwd' s)
            t × v = successful (eval γ e bot)
            v' = fromMaybe identity (fst <$> v_expect_opt) v
            { γ: γ', e: e' } = evalBwd (erase <$> γ) (erase e) v' t
            s' = desugBwd' e' :: S.Expr _
            _ × v'' = successful (eval γ' (successful (desugFwd' s')) true)
            src = render (pretty s)
            srcExp = show (erase s)
         case parse src program of
               Left msg -> fail msg
               Right newProg -> do
                  trace ("1:\n" <> src) \_ -> do
                     case bol of 
                        true -> do 
                           let newExp = show newProg
                           case (eq (erase s) newProg) of 
                              false -> do 
                                 liftEffect (log ("SRC\n" <> srcExp))
                                 liftEffect (log ("NEW\n" <> newExp))
                                 fail "not equal"
                              true -> do 
                                 unless (isGraphical v'') (checkPretty "Value" expected v'')
                                 trace ("\n" <> src) \_ -> do
                                    unless (isGraphical v'') (checkPretty "Value" expected v'')
                                    case snd <$> v_expect_opt of
                                       Nothing -> pure unit
                                       Just file_expect ->
                                          loadFile (Folder "fluid/example") file_expect >>= flip (checkPretty "Source selection") s'
                        false -> do 
                           --let newExp = show newProg
                           --liftEffect (log ("SRC\n" <> srcExp))
                           liftEffect (logShow (eq (erase s) newProg))
                           unless (isGraphical v'') (checkPretty "Value" expected v'')
                           trace ("\n" <> src) \_ -> do
                              unless (isGraphical v'') (checkPretty "Value" expected v'')
                              case snd <$> v_expect_opt of
                                 Nothing -> pure unit
                                 Just file_expect ->
                                    loadFile (Folder "fluid/example") file_expect >>= flip (checkPretty "Source selection") s'
             

         
test :: Boolean -> File -> String -> Test Unit
test b file expected = testWithSetup b  file expected Nothing (openWithDefaultImports file)

testBwd :: Boolean -> File -> File -> Selector -> String -> Test Unit
testBwd b file file_expect δv expected =
   testWithSetup b  file' expected (Just (δv × (folder <> file_expect))) (openWithDefaultImports file')
   where
   folder = File "slicing/"
   file' = folder <> file

testLink :: Boolean ->  LinkFigSpec -> Selector -> String -> Test Unit
testLink _  spec@{ x } δv1 v2_expect =
   before (loadLinkFig spec) $
      it ("linking/" <> show spec.file1 <> " <-> " <> show spec.file2)
         \{ γ0, γ, e1, e2, t1, t2, v1 } ->
            let
               { v': v2' } = successful $ linkResult x γ0 γ e1 e2 t1 t2 (δv1 v1)
            in
               checkPretty "Linked output" v2_expect v2'

testWithDataset :: Boolean -> File -> File -> Test Unit
testWithDataset b dataset file = do
   testWithSetup b  file "" Nothing $ do
      γ0 × γ <- openDatasetAs dataset "data"
      ((γ0 <+> γ) × _) <$> open file
