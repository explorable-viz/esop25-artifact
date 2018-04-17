import { __nonNull, assert, as, make } from "./util/Core"
import { Cons, List, Nil } from "./BaseTypes"
import { ctrToDataType } from "./DataType"
import { Env, EnvEntries, EnvEntry, ExtendEnv } from "./Env"
import { get, has } from "./FiniteMap"
import { PrimBody, PrimResult } from "./Primitive"
import { Expr, Trace, Traced, Trie, Value } from "./Syntax"
import { PersistentObject } from "./Runtime";

export module Eval {

export class Evaluand extends PersistentObject {
   j: EnvEntries
   e: Expr

   static make (j: EnvEntries, e: Expr): Evaluand {
      const this_: Evaluand = make(Evaluand, j, e)
      this_.j = j
      this_.e = e
      return this_
   }
}

export type Result<T> = [Traced, Env, T]    // tv, ρ, σv
type Results = [List<Traced>, Env, Object]      // tvs, ρ, σv

function closeDefs (δ_0: Expr.RecDefs, ρ: Env, δ: Expr.RecDefs): Env {
   if (δ_0 instanceof Expr.EmptyRecDefs) {
      return ρ
   } else 
   if (δ_0 instanceof Expr.ExtendRecDefs) {
      return ExtendEnv.make(closeDefs(δ_0.δ, ρ, δ), δ_0.def.x.str, EnvEntry.make(ρ, δ, δ_0.def.def))
   } else {
      return assert(false)
   }
}

// Not capturing the polymorphic type of the nested trie κ (which has a depth of n >= 0).
function evalSeq (ρ: Env, κ: Object, es: List<Expr>): Results {
   if (Cons.is(es)) {
      const σ: Trie<Object> = as(κ as Trie<Object>, Trie.Trie),
            [tv, ρʹ, κʹ]: Result<Object> = eval_(ρ, es.head, σ),
            [tvs, ρʺ, κʺ]: Results = evalSeq(ρ, κʹ, es.tail)
      return [Cons.make(tv, tvs), Env.concat(ρʹ, ρʺ), κʺ]
   } else
   if (Nil.is(es)) { // TS bug requires guards in this order
      return [Nil.make(), Env.empty(), κ]
   } else {
      return assert(false)
   }
}

// Output trace and value are unknown (null) iff σ is empty (i.e. a variable trie).
export function eval_<T> (ρ: Env, e: Expr, σ: Trie<T>): Result<T> {
   const k: Evaluand = Evaluand.make(ρ.entries(), e)
   if (Trie.Var.is(σ)) {
      const entry: EnvEntry = EnvEntry.make(ρ, Expr.EmptyRecDefs.make(), e)
      return [Traced.at(k, null, null), Env.singleton(σ.x.str, entry), σ.body]
   } else {
      if (e instanceof Expr.Constr && Trie.Constr.is(σ) && has(σ.cases, e.ctr.str)) {
         const ctr: string = e.ctr.str
         assert(ctrToDataType.has(ctr), "No such constructor.", e)
         assert(ctrToDataType.get(ctr)!.ctrs.get(ctr)!.length === e.args.length, "Arity mismatch.", e)
         const σʹ: Object = get(σ.cases, e.ctr.str)!,
               [tvs, ρʹ, κ]: Results = evalSeq(ρ, σʹ, e.args)
         // have to cast κ without type information on constructor
         return [Traced.at(k, Trace.Empty.at(k), Value.Constr.at(k, e.ctr, tvs)), ρʹ, κ as T]
      } else
      if (e instanceof Expr.ConstInt && Trie.ConstInt.is(σ)) {
         return [Traced.at(k, Trace.Empty.at(k), Value.ConstInt.at(k, e.val)), Env.empty(), σ.body]
      } else
      if (e instanceof Expr.ConstStr && Trie.ConstStr.is(σ)) {
         return [Traced.at(k, Trace.Empty.at(k), Value.ConstStr.at(k, e.val)), Env.empty(), σ.body]
      } else
      if (e instanceof Expr.Fun && Trie.Fun.is(σ)) {
         return [Traced.at(k, Trace.Empty.at(k), Value.Closure.at(k, ρ, e.σ)), Env.empty(), σ.body]
      } else
      if (e instanceof Expr.PrimOp && Trie.Fun.is(σ)) {
         return [Traced.at(k, Trace.Empty.at(k), e.op), Env.empty(), σ.body]
      } else
      if (e instanceof Expr.Var || e instanceof Expr.OpName) {
         const x: string = e instanceof Expr.OpName ? e.opName.str : e.ident.str
         if (!ρ.has(x)) {
            return assert(false, "Name not found.", x)
         } else {
            const {ρ: ρʹ, δ, e: eʹ}: EnvEntry = ρ.get(x)!,
                  [tv, ρʺ, σv]: Result<T> = eval_(closeDefs(δ, ρʹ, δ), eʹ, σ),
                  t: Trace = e instanceof Expr.OpName 
                     ? Trace.OpName.at(k, e.opName, __nonNull(tv.trace))
                     : Trace.Var.at(k, e.ident, __nonNull(tv.trace))
            return [Traced.at(k, t, tv.val), ρʺ, σv]
         }
      } else
      if (e instanceof Expr.Let) {
         const [tu, ρʹ, σu]: Result<Expr> = eval_(ρ, e.e, e.σ),
               [tv, ρʺ, κ]: Result<T> = eval_<T>(Env.concat(ρ, ρʹ), σu, σ)
         return [Traced.at(k, Trace.Let.at(k, tu, __nonNull(tv.trace)), tv.val), ρʺ, κ]
      } else 
      // See 0.3.4 release notes for semantics.
      if (e instanceof Expr.LetRec) {
         const ρʹ: Env = closeDefs(e.δ, ρ, e.δ),
               [tv, ρʺ, σv]: Result<T> = eval_<T>(ρʹ, e.e, σ)
         return [Traced.at(k, Trace.LetRec.at(k, e.δ, __nonNull(tv.trace)), tv.val), ρʺ, σv]
      } else
      if (e instanceof Expr.MatchAs) {
         const [tu, ρʹ, σu]: Result<Expr> = eval_(ρ, e.e, e.σ),
               [tv, ρʺ, κ]: Result<T> = eval_<T>(Env.concat(ρ, ρʹ), σu, σ)
         return [Traced.at(k, Trace.Match.at(k, tu, __nonNull(tv.trace)), tv.val), ρʺ, κ]
      } else
      if (e instanceof Expr.App) {
         const [tf, ,]: Result<null> = eval_(ρ, e.func, Trie.Fun.make(null)),
               f: Value | null = tf.val
         if (f instanceof Value.Closure) {
            const [tu, ρʹ, σʹu]: Result<Expr> = eval_(ρ, e.arg, f.σ),
                  [tv, ρʺ, σv]: Result<T> = eval_<T>(Env.concat(f.ρ, ρʹ), σʹu, σ)
            return [Traced.at(k, Trace.App.at(k, tf, tu, __nonNull(tv.trace)), tv.val), ρʺ, σv]
         } else
         if (f instanceof Value.PrimOp) {
            const [tu, , σʹu]: Result<PrimBody<T>> = eval_(ρ, e.arg, f.σ),
                  [v, σv]: PrimResult<T> = σʹu(tu.val, σ)(k)
            return [Traced.at(k, Trace.PrimApp.at(k, tf, tu), v), Env.empty(), σv]
         } else {
            return assert(false, "Not a function.", f)
         }
      }
   }
   return assert(false, "Demand mismatch.", e, σ)
}

}
