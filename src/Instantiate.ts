import { absurd } from "./util/Core"
import { List, Pair } from "./BaseTypes"
import { Env } from "./Env"
import { Eval, Runtime } from "./Eval"
import { Expr, Trace, Traced, Trie, TrieBody, Value } from "./Syntax"

export function instantiate (ρ: Env): (e: Expr.Expr) => Traced {
   return function (e: Expr.Expr): Traced {
      const i: Runtime<Expr> = Runtime.make(ρ.entries(), e)
      if (e instanceof Expr.ConstInt) {
         return Traced.at(i, Trace.Empty.at(i), Value.ConstInt.at(i, e.val))
      } else
      if (e instanceof Expr.ConstStr) {
         return Traced.at(i, Trace.Empty.at(i), Value.ConstStr.at(i, e.val))
      } else
      if (e instanceof Expr.Constr) {
         // Parser ensures constructors agree with constructor signatures.
         return Traced.at(i, Trace.Empty.at(i), Value.Constr.at(i, e.ctr, e.args.map(instantiate(ρ))))
      } else
      if (e instanceof Expr.Fun) {
         // No need to use "unknown" environment here because we have ρ.
         return Traced.at(i, Trace.Empty.at(i), Value.Closure.at(i, ρ, instantiateTrie(ρ, e.σ)))
      } else
      if (e instanceof Expr.PrimOp) {
         return Traced.at(i, Trace.Empty.at(i), Value.PrimOp.at(i, e.op))
      } else
      if (e instanceof Expr.Var) {
         return Traced.at(i, Trace.Var.at(i, e.x, null), null)
      } else
      if (e instanceof Expr.Let) {
         // Trace must still be null even though I know "statically" which branch will be taken.
         const t: Trace = Trace.Let.at(i, instantiate(ρ)(e.e), instantiateTrie(ρ, e.σ) as Trie.Var<Traced>, null)
         return Traced.at(i, t, null)
      } else
      if (e instanceof Expr.LetRec) {
         const δ: List<Trace.RecDef> = e.δ.map(def => {
            const j: Runtime<Expr.RecDef> = Runtime.make(ρ.entries(), def)
            return Trace.RecDef.at(j, def.x, instantiate(ρ)(def.e))
         })
         const t: Trace = Trace.LetRec.at(i, δ, instantiate(Eval.closeDefs(δ, ρ, δ))(e.e))
         return Traced.at(i, t, null)
      } else
      if (e instanceof Expr.MatchAs) {
         return Traced.at(i, Trace.MatchAs.at(i, instantiate(ρ)(e.e), instantiateTrie(ρ, e.σ), null), null)
      } else
      if (e instanceof Expr.App) {
         return Traced.at(i, Trace.App.at(i, instantiate(ρ)(e.func), instantiate(ρ)(e.arg), null), null)
      } else
      if (e instanceof Expr.PrimApp) {
         return Traced.at(i, Trace.PrimApp.at(i, instantiate(ρ)(e.e1), e.opName, instantiate(ρ)(e.e2)), null)
      } else {
         return absurd()
      }
   }
}

function instantiateTrieBody (ρ: Env, κ: TrieBody<Expr>): TrieBody<Traced> {
   if (κ instanceof Trie.Trie) {
      return instantiateTrie(ρ, κ)
   } else {
      return instantiate(ρ)(κ)
   }
}

// Can't give this a more specific type without type variables of kind * -> *.
function instantiateTrie (ρ: Env, σ: Trie<Expr>): Trie<Traced> {
   if (Trie.Var.is(σ)) {
      return Trie.Var.make(σ.x, instantiateTrieBody(ρ, σ.body))
   } else
   if (Trie.ConstInt.is(σ)) {
      return Trie.ConstInt.make(instantiateTrieBody(ρ, σ.body))
   } else
   if (Trie.ConstStr.is(σ)) {
      return Trie.ConstStr.make(instantiateTrieBody(ρ, σ.body))
   } else
   if (Trie.Constr.is(σ)) {
      return Trie.Constr.make(σ.cases.map(
         ({ fst: ctr, snd: κ }: Pair<string, TrieBody<Expr>>): Pair<string, TrieBody<Traced>> => {
            return Pair.make(ctr, instantiateTrieBody(ρ, κ))
         })
      )
   } else
   if (Trie.Fun.is(σ)) {
      return Trie.Fun.make(instantiateTrieBody(ρ, σ.body))
   } else {
      return absurd()
   }
}
