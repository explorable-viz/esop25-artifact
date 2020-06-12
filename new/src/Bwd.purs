module Bwd where

import Prelude hiding (absurd, join)
import Data.Either (Either(..))
import Data.List (List(..)) as L
import Data.List (List, (:), foldMap)
import Data.Map (update)
import Data.Tuple (Tuple(..))
import Bindings ((:+:), (↦), ε, find, remove)
import Elim (Elim(..))
import Expl (Expl(..)) as T
import Expl (Expl, Match(..), Match2(..))
import Expr (Cont, Elim2(..), Expr(..), RawExpr(..))
import Lattice (class Selectable, Selected, (∨), bot, join)
import Util (T3(..), absurd, error, successful, (≜))
import Val (Env, Val(..), BinaryOp(..), UnaryOp(..))
import Val (RawVal(..)) as V

unmatch :: forall k . Env -> Match k -> Tuple Env Env
unmatch ρ (MatchVar x)
   =  let Tuple v ρ' = successful (remove x ρ)
      in  Tuple ρ' (ε :+: x ↦ v)
unmatch ρ (MatchTrue k)    = Tuple ρ ε
unmatch ρ (MatchFalse k)   = Tuple ρ ε
unmatch ρ (MatchPair ξ ξ')
   =  let Tuple ρ'  ρ2 = unmatch ρ  ξ'
          Tuple ρ'' ρ1 = unmatch ρ' ξ
      in  Tuple ρ (ρ1 <> ρ2)
unmatch ρ (MatchNil k)     = Tuple ρ ε
unmatch ρ (MatchCons { nil: k, cons: Tuple ξ ξ' })
   =  let Tuple ρ'  ρ2 = unmatch ρ  ξ'
          Tuple ρ'' ρ1 = unmatch ρ' ξ
      in  Tuple ρ (ρ1 <> ρ2)

bound_vars :: forall k . Env -> Match k -> Env
bound_vars ρ (MatchVar x)     = ε :+: x ↦ successful (find x ρ)
bound_vars _ (MatchTrue k)    = ε
bound_vars _ (MatchFalse k)   = ε
bound_vars ρ (MatchPair ξ ξ') = bound_vars ρ ξ <> bound_vars ρ ξ'
bound_vars _ (MatchNil k)     = ε
bound_vars ρ (MatchCons { nil: k, cons: Tuple ξ ξ' }) = bound_vars ρ ξ <> bound_vars ρ ξ'

bound_vars2 :: Env -> Match2 -> Env
bound_vars2 ρ (MatchVar2 x) = ε :+: x ↦ successful (find x ρ)
bound_vars2 ρ (MatchConstr (Tuple _ ξs) _) = foldMap (bound_vars2 ρ) ξs

match_bwd :: forall k . Selectable k => Env -> k -> Selected -> Match k -> Tuple Val (Elim k)
-- var
match_bwd (ε :+: x ↦ v) κ α (MatchVar x') = Tuple v (ElimVar (x ≜ x') κ)
-- true
match_bwd ε κ α (MatchTrue κ')  = Tuple (Val α V.True) (ElimBool { true: κ, false: bot κ' })
-- false
match_bwd ε κ α (MatchFalse κ') = Tuple (Val α V.False) (ElimBool { true: bot κ', false: κ })
-- pair
match_bwd ρ κ α (MatchPair ξ ξ') =
   let ρ1 = bound_vars ρ ξ
       ρ2 = bound_vars ρ ξ'
       Tuple v' σ  = match_bwd ρ2 κ α ξ'
       Tuple v  τ  = match_bwd ρ1 σ α ξ
   in  Tuple (Val α (V.Pair v v')) (ElimPair τ)
-- nil
match_bwd ε κ α (MatchNil σ) = Tuple (Val α V.Nil) (ElimList {nil: κ, cons: bot σ})
-- cons
match_bwd ρ κ α (MatchCons { nil: κ', cons: Tuple ξ ξ'}) =
   let ρ1 = bound_vars ρ ξ
       ρ2 = bound_vars ρ ξ'
       Tuple v' σ  = match_bwd ρ2 κ α ξ'
       Tuple v  τ  = match_bwd ρ1 σ α ξ
   in  Tuple (Val α (V.Cons v v')) (ElimList {nil: bot κ, cons: τ})
match_bwd _ _ _ _ = error absurd

match_bwd2 :: Env -> Cont -> Selected -> Match2 -> Tuple Val Elim2
match_bwd2 (ε :+: x ↦ v) κ α (MatchVar2 x')     = Tuple v (ElimVar2 (x ≜ x') κ)
match_bwd2 _ _ _ (MatchVar2 x')                 = error absurd
match_bwd2 ρ κ α (MatchConstr (Tuple c ξs) κs)  =
   let Tuple vs κ = matchArgs_bwd ρ κ α ξs in
   Tuple (Val α $ V.Constr c vs) (ElimConstr $ update (const $ pure κ) c $ map bot κs)

matchArgs_bwd :: Env -> Cont -> Selected -> List Match2 -> Tuple (List Val) Cont
matchArgs_bwd ρ κ α L.Nil     = Tuple L.Nil κ
matchArgs_bwd ρ κ α (ξ : ξs)  =
   let ρ1            = bound_vars2 ρ ξ -- revisit once Min has fixed match_bwd above
       ρ2            = foldMap (bound_vars2 ρ) ξs
       Tuple vs κ'   = matchArgs_bwd ρ2 κ α ξs
       Tuple v σ     = match_bwd2 ρ1 κ' α ξ in
   Tuple (v : vs) $ Right σ

eval_bwd :: Val -> Expl -> T3 Env Expr Selected
-- true
eval_bwd (Val α V.True ) T.True = T3 ε (Expr α True) α
-- false
eval_bwd (Val α V.False) T.False = T3 ε (Expr α False) α
-- pair
eval_bwd (Val α (V.Pair v1 v2)) (T.Pair t1 t2)
   = let T3 ρ1  e1  α1 = eval_bwd v1 t1
         T3 ρ2  e2  α2 = eval_bwd v2 t2
     in  T3 (join ρ1 ρ2) (Expr α (Pair e1 e2)) (α ∨ α1 ∨ α2)
-- var
eval_bwd (Val α v) (T.Var x) =
   T3 (ε :+: x ↦ (Val α v)) (Expr α (Var x)) false
-- int
eval_bwd (Val α (V.Int n)) (T.Int tn) = T3 ε (Expr α (Int n)) α
-- op
eval_bwd (Val α (V.Binary (BinaryOp s bin))) (T.Op op)
   = T3 (ε :+: op ↦ (Val α (V.Binary (BinaryOp s bin)))) (Expr α (Op op)) false
eval_bwd (Val α (V.Unary (UnaryOp s una))) (T.Op op)
   = T3 (ε :+: op ↦ (Val α (V.Unary (UnaryOp s una)))) (Expr α (Op op)) false
-- nil
eval_bwd (Val α V.Nil) T.Nil = T3 ε (Expr α Nil) α
-- cons
eval_bwd (Val α (V.Cons u v)) (T.Cons tT uU)
   = let T3 ρ  e  α'  = eval_bwd u tT
         T3 ρ' e' α'' = eval_bwd v uU
     in  T3 (join ρ ρ') (Expr α (Cons e e')) (α ∨ α' ∨ α'')
-- apply
eval_bwd v (T.App t u ξ t')
   = case eval_bwd v t' of
      T3 (ρ1_ρ :+: f ↦ Val _ (V.Closure ρ1' δ σ)) e α ->
         let Tuple ρ1 ρ         = unmatch ρ1_ρ ξ
             Tuple v' σ'        = match_bwd ρ e α ξ
             T3 ρ'  e'  α'      = eval_bwd v' u
             T3 ρ'' e'' α''     = eval_bwd (Val α (V.Closure (ρ1 ∨ ρ1') δ (σ ∨ σ'))) t
         in  T3 (ρ' ∨ ρ'') (e' ∨ e'') (α' ∨ α'')
      _ -> error absurd
-- -- binary-apply
-- eval_bwd (Val α (V.Int n)) (T.BinaryApp t op u)
--    = case t, u of
--       (T.Int val_t), (T.Int val_u) ->
--          let T3 ρ  e  α'  = eval_bwd (Val α (V.Int val_t)) t
--              T3 ρ' e' α'' = eval_bwd (Val α (V.Int val_u)) u
--          in  T3 (ρ ∨ ρ') (Expr α (BinaryApp e e')) α
--       _, _ -> error absurd
-- -- apply-prim
-- eval_bwd (Val α (V.Int n)) (T.AppOp t u)
--    = case t of
--       (T.Op op) -> let val_t = successful (find op primitives)
--                        T3 ρ e α' = eval_bwd val_t t
--                    in  case u of
--                         (T.Int i) ->
--                            let val_u = Val α i
--                                T3 ρ' e' α'' = eval_bwd val_u u
--                            in  T3 (ρ ∨ ρ') (e ∨ e') (α)
--                         (T.Var x) ->
--                         _
--       _ -> error absurd
-- let
-- eval_bwd val (T.Let x t1 t2) = ...
-- -- let-rec
-- eval_bwd val (T.Letrec x t1 t2) = ...
eval_bwd _ _ = error absurd