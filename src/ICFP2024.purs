module ICFP2024 where

import Prelude

import App.Fig (drawLinkedInputsFig, runAffs_)
import App.Util.Select (field, listElement)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple (uncurry)
import Effect (Effect)
import Lattice (neg)
import Module (File(..))
import Test.Specs (linkedInputs_spec3, linkedInputs_spec4, linkedInputs_spec5)
import Test.Util.Suite (TestLinkedInputsSpec, loadLinkedInputsTest)

linkedInputs_spec6 :: TestLinkedInputsSpec
linkedInputs_spec6 =
   { spec:
        { divId: "fig-1"
        , file: File "energy"
        , x2: "non_renewables"
        , x2File: File "non-renewables"
        , x1: "renewables"
        , x1File: File "renewables"
        }
   , δv: Left $ listElement 3 (field "output" neg)
   , v'_expect: Nothing
   }

main :: Effect Unit
main =
   runAffs_ (uncurry drawLinkedInputsFig)
      [ loadLinkedInputsTest linkedInputs_spec5
      , loadLinkedInputsTest linkedInputs_spec3
      , loadLinkedInputsTest linkedInputs_spec4
      ]
