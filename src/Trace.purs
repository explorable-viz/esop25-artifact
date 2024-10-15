module Trace where

import Prelude

import Bind (Var)
import Data.Exists (Exists)
import Data.List (List)
import Data.Maybe (Maybe)
import Data.Set (Set, empty, singleton, unions)
import DataType (Ctr)
import Dict (Dict)
import Expr (class BV, RecDefs, bv)
import Lattice (Raw)
import Util (type (×))
import Val (Array2, ForeignOp', Val)

data Trace
   = Var Var
   | Op Var
   | Const
   | Record (Dict Trace)
   | Dictionary (List (String × Trace × Trace)) (Dict (Raw Val))
   | Constr Ctr (List Trace)
   | Matrix (Array2 Trace) (Var × Var) (Int × Int) Trace
   | Project Trace Var
   | DProject Trace (Maybe Trace) Var
   | App Trace Trace AppTrace
   | Let VarDef Trace
   | LetRec (Raw RecDefs) Trace

data AppTrace
   = AppClosure (Set Var) Match Trace
   -- these two forms represent partial (unsaturated) applications
   | AppForeign Int ForeignTrace -- record number of arguments
   | AppConstr Ctr

data ForeignTrace' t = ForeignTrace' (ForeignOp' t) (Maybe t)
newtype ForeignTrace = ForeignTrace (String × Exists ForeignTrace')

data VarDef = VarDef Match Trace

data Match
   = MatchVar Var (Raw Val)
   | MatchVarAnon (Raw Val)
   | MatchConstr Ctr (List Match)
   | MatchRecord (Dict Match)
   | MatchDict (Dict Match)

instance BV Match where
   bv (MatchVar x _) = singleton x
   bv (MatchVarAnon _) = empty
   bv (MatchConstr _ ws) = unions (bv <$> ws)
   bv (MatchRecord xws) = unions (bv <$> xws)
   bv (MatchDict xws) = unions (bv <$> xws)