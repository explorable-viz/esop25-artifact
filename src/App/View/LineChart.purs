module App.View.LineChart where

import Prelude hiding (absurd)

import App.Util (class Reflect, Handler, Renderer, SelState, Selectable, Selector, 𝕊, from, get_intOrNumber, record, selector, unsafeEventData)
import App.Util.Selector (field, lineChart, linePoint, listElement)
import Data.List (List(..), (:))
import Data.Maybe (Maybe)
import Data.Profunctor.Strong ((&&&))
import Data.Tuple (uncurry)
import DataType (cLinePlot, f_caption, f_data, f_name, f_plots, f_x, f_y)
import Dict (Dict)
import Primitive (string, unpack)
import Util (type (×), Endo, (!), (×))
import Util.Map (get)
import Val (BaseVal(..), Val(..))
import Web.Event.Event (EventType, target, type_)
import Web.Event.EventTarget (EventTarget)

newtype LineChart = LineChart
   { caption :: Selectable String
   , plots :: Array LinePlot
   }

newtype LinePlot = LinePlot
   { name :: Selectable String
   , data :: Array Point
   }

newtype Point = Point
   { x :: Selectable Number
   , y :: Selectable Number
   }

foreign import drawLineChart :: Renderer LineChart

instance Reflect (Dict (Val (SelState 𝕊))) Point where
   from r = Point
      { x: get_intOrNumber f_x r
      , y: get_intOrNumber f_y r
      }

instance Reflect (Dict (Val (SelState 𝕊))) LinePlot where
   from r = LinePlot
      { name: unpack string (get f_name r)
      , data: record from <$> from (get f_data r)
      }

instance Reflect (Dict (Val (SelState 𝕊))) LineChart where
   from r = LineChart
      { caption: unpack string (get f_caption r)
      , plots: from <$> (from (get f_plots r) :: Array (Val (SelState 𝕊))) :: Array LinePlot
      }

instance Reflect (Val (SelState 𝕊)) LinePlot where
   from (Val _ (Constr c (u1 : Nil))) | c == cLinePlot = record from u1

lineChartHandler :: Handler
lineChartHandler = (target &&& type_) >>> pos >>> uncurry togglePoint
   where
   togglePoint :: Int × Int -> Endo (Selector Val)
   togglePoint (i × j) =
      lineChart
         <<< field f_plots
         <<< listElement i
         <<< linePoint j

   -- [Unsafe] 0-based indices of line plot and point within line plot.
   pos :: Maybe EventTarget × EventType -> (Int × Int) × Selector Val
   pos (tgt_opt × ty) = (xy ! 0 × xy ! 1) × selector ty
      where
      xy = unsafeEventData tgt_opt ! 0 :: Array Int
