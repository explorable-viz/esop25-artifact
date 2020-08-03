module Test.Main where

import Prelude
import Data.Bitraversable (bitraverse)
import Data.Tuple (uncurry)
import Effect (Effect)
import Effect.Aff (Aff)
import Test.Spec (SpecT, before, it)
import Test.Spec.Assertions (shouldEqual)
import Test.Spec.Mocha (runMocha)
import Bwd (eval_bwd)
import DataType (dataTypeFor, typeName)
import Desugar (SExpr, desugar)
import Expr (Expr)
import Eval (eval)
import Fwd (eval_fwd)
import Lattice (𝔹)
import Module (loadModule, openDatasetAs, openWithImports)
import Pretty (pretty, render)
import Primitive (primitives)
import Util (type (×), (×), successful)
import Val (Env, Val(..), RawVal(..))
-- import Test.Desugar(lcomp1, lcomp2, lcomp3, lcomp4, lcomp1_eval, lcomp2_eval, lcomp3_eval, lcomp4_eval, lseq1, lseq1_eval)

-- Don't enforce expected values for graphics tests (values too complex).
isGraphical :: forall a . Val a -> Boolean
isGraphical Hole                 = false
isGraphical (Val _ (Constr c _)) = typeName (successful $ dataTypeFor c) == "GraphicsElement"
isGraphical (Val _ _)            = false

-- whether slicing is currently enabled in the tests
slicing :: Boolean
slicing = true

run :: forall a . SpecT Aff Unit Effect a → Effect Unit
run = runMocha -- nicer name

test' :: String -> Aff (Env 𝔹 × Expr 𝔹) -> String -> SpecT Aff Unit Effect Unit
test' name setup expected =
   before setup $
      it name $ \(ρ × e) -> do
         case successful $ eval ρ e of
            t × v -> do
               unless (isGraphical v) $
                  (render $ pretty v) `shouldEqual` expected
               when slicing do
                  let ρ' × e' × α'  = eval_bwd v t
                      v'            = eval_fwd ρ' e' true
                  unless (isGraphical v) $
                     (render $ pretty v') `shouldEqual` expected

test :: String -> String -> SpecT Aff Unit Effect Unit
test file = test' file (openWithImports file)

testWithDataset :: String -> String -> SpecT Aff Unit Effect Unit
testWithDataset dataset file =
   flip (test' file) "" $
      bitraverse (uncurry openDatasetAs) openWithImports (dataset × "data" × file) <#>
      (\(ρ × (ρ' × e)) -> (ρ <> ρ') × e)

desugarTest :: String -> SExpr -> String -> SpecT Aff Unit Effect Unit
desugarTest name s expected =
   before (loadModule "prelude" primitives) $
      it name $ \ρ ->
         case successful $ eval ρ (desugar s) of
            t × v -> (render $ pretty v) `shouldEqual` expected

main :: Effect Unit
main = do
{-
   -- desugaring
   run $ desugarTest "list-comp-1" lcomp1 lcomp1_eval
   run $ desugarTest "list-comp-2" lcomp2 lcomp2_eval
   run $ desugarTest "list-comp-3" lcomp3 lcomp3_eval
   run $ desugarTest "list-comp-4" lcomp4 lcomp4_eval
   run $ desugarTest "list-seq-1" lseq1 lseq1_eval
   -- slicing
   run $ test "arithmetic" "42"
   run $ test "compose" "5"
   run $ test "factorial" "40320"
   run $ test "filter" "[8, 7]"
   run $ test "flatten" "[(3, \"simon\"), (4, \"john\"), (6, \"sarah\"), (7, \"claire\")]"
   run $ test "foldr_sumSquares" "661"
   run $ test "lexicalScoping" "\"6\""
   run $ test "length" "2"
   run $ test "lookup" "Some \"sarah\""
   run $ test "map" "[5, 7, 13, 15, 4, 3, -3]"
   run $ test "mergeSort" "[1, 2, 3]"
   run $ test "normalise" "(33, 66)"
   run $ test "pattern-match" "4"
   run $ test "reverse" "[2, 1]"
-}
   run $ test "zipWith" "[[10], [12], [20]]"
{-
   -- graphics
   run $ testWithDataset "renewables-restricted" "graphics/background"
-}
   run $ testWithDataset "renewables-restricted" "graphics/grouped-bar-chart"
   run $ testWithDataset "renewables-restricted" "graphics/line-chart"
   run $ testWithDataset "renewables-restricted" "graphics/stacked-bar-chart"
   -- scratchpad
   run $ test "temp" "2.0"
