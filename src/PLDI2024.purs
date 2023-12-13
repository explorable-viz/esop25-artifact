module PLDI2024 where

import Prelude

import App.Fig (drawLinkedInputsFig, runAffs_)
import App.Util.Select (field, listElement)
import Data.Either (Either(..))
import Data.Tuple (uncurry)
import Effect (Effect)
import Lattice (neg)
import Module (File(..))
import Test.Specs (linkedInputs_spec1, linkedInputs_spec2)
import Test.Util.Suite (loadLinkedInputsTest, TestLinkedInputsSpec)

linkedInputs_spec_pres :: TestLinkedInputsSpec
linkedInputs_spec_pres =
   { spec:
        { divId: "fig-3"
        , file: File "water"
        , x1: "countries"
        , x1File: File "countries"
        , x2: "cities"
        , x2File: File "cities"
        }
   , δv: Left $ listElement 0 (field "farms" neg) >>> listElement 1 (field "farms" neg)
   , v'_expect: "({country : \"Germany\", name : \"Berlin\", water : ⸨130⸩} : ({country : \"Germany\", name : \"Munich\", water : ⸨80⸩} : ({country : \"Germany\", name : \"Hamburg\", water : ⸨60⸩} : ({country : \"UK\", name : \"London\", water : 200} : ({country : \"UK\", name : \"Birmingham\", water : 50} : ({country : \"UK\", name : \"Manchester\", water : 35} : ({country : \"Bulgaria\", name : \"Sofia\", water : 55} : ({country : \"Poland\", name : \"Warsaw\", water : 65} : ({country : \"Turkey\", name : \"Istanbul\", water : 375} : [])))))))))"
   }

linkedInputs_spec3 :: TestLinkedInputsSpec
linkedInputs_spec3 =
   { spec:
        { divId: "fig-3"
        , file: File "energy"
        , x1: "renewables"
        , x1File: File "renewables"
        , x2: "non_renewables"
        , x2File: File "non-renewables"
        }
   , δv: Left $ listElement 108 (field "output" neg)
   , v'_expect: "" -- no point with expected value here
   }

main :: Effect Unit
main =
   runAffs_ (uncurry drawLinkedInputsFig)
      [ loadLinkedInputsTest linkedInputs_spec1
      , loadLinkedInputsTest linkedInputs_spec2
      , loadLinkedInputsTest linkedInputs_spec3
      ]
