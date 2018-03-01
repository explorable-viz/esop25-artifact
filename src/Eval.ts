import { zip } from "./util/Array"
import { __nonNull, assert, as } from "./util/Core"
import { extend, map, union } from "./util/Map"
import { eq } from "./util/Ord"
import { __def, __defLocal, key, keyP } from "./Memo"
import { Env, EnvEntry, Expr, Lex, Trace, Traced, Trie, Value } from "./Syntax"
import * as AST from "./Syntax"

export module Eval {

type EvalResult = [Traced, Env, Traced] // v, ρ, σv

function __result (α: Addr, t: Trace, v: Value.Value | null, ρ: Env, κ: Traced): EvalResult {
   return [Traced.at(α, t, v), ρ, κ]
}

__def(eval)
export function eval_ (ρ: Env): (σ: Trie<Object> | null) => (e: Expr.Expr) => EvalResult {
   return __defLocal(key(eval, arguments), function withDemand (σ: Trie<Object>): (e: Expr.Expr) => EvalResult {
      return __defLocal(key(withDemand, arguments), function withEnv (e: Expr.Expr): EvalResult {
         const α: Addr = key(withEnv, arguments)
         assert(e !== undefined, "Missing constructor argument?")
         if (σ instanceof AST.VarTrie) {
            // TODO
         } else {
            if (e instanceof AST.EmptyTrace) {
               const v: Value.Value = __nonNull(e.val)
               if (v instanceof Value.Constr) {               
                  if (σ instanceof AST.ConstrTrie) {
                     const σʹ: Trie<Traced> = σ.cases.get(v.ctr.str)
                     const β: Addr = keyP(α, "val")
                     return __result(α, t, Value.Constr.at(β, v.ctr, v.args.map(eval_(ρ)(null))))
                  } else {
                     return assert(false, "Demand mismatch.")
                  }
               } else
               if (v instanceof Value.ConstInt) {
                  return e
               } else
               if (v instanceof Value.ConstStr) {
                  return e
               }
            } else
            if (e instanceof AST.Fun) {
               if (σ instanceof AST.FunTrie) {
                  return __result(α, t, AST.Closure.at(keyP(α, "val"), ρ, [], t), new Map, σ.body)
               } else {
                  assert(false, "Demand m ismatch.")
               }
            } else
            // See 0.4.6 release notes on why undefined values map to ⊥.
            if (e instanceof AST.OpName) {
               if (!ρ.has(e.opName.str)) {
                  return assert(false, "Operator not found.", t.opName)
               } else {
                  return __result(α, e.trace, as(ρ.get(t.opName.str), AST.PrimOp))
               }
            } else
            if (e instanceof Expr.Var) {
               const cls: EnvEntry = __nonNull(ρ.get(e.ident.str)),
                     [tv, ρʺ, σv]: EvalResult = eval_(cls.ρ)(σ)(cls.e)
               return __result(α, Trace.Var.at(α, e.ident, tv.trace), tv.val, ρʺ, σv)
            } else
            if (e instanceof Expr.Let) {
               const [tu, ρʹ, σu]: EvalResult = eval_(ρ)(e.σ)(e.e),
                     [tv, ρʺ, κ]: EvalResult = eval_(union([ρ, ρʹ]))(σ)(σu)
               return __result(α, Trace.Let.at(keyP(α, "trace"), tu, tv.trace), tv.val, ρʺ, κ)
            } else 
            // See 0.3.4 release notes for semantics.
            if (e instanceof AST.LetRec) {
               const defs: AST.RecDefinition[] = e.bindings.map(binding => binding.def),
                     fs: Value.Closure[] = closeDefs(ρ, defs),
                     ρʹ: Env = extend(ρ, zip(defs.map(def => def.name.str), fs)),
                     χ: EvalResult = eval_(ρʹ)(null)(Traced.at(keyP(α, "1"), t.body, null, e.val)),
                     bindings: AST.RecBinding[] = zip(t.bindings, fs).map(bindRecDef)
               return __result(α, AST.LetRec.at(keyP(α, "trace"), bindings, χ.expr.trace), χ.expr.val)
            } else
            if (e instanceof Expr.MatchAs) {
               const [tu, ρʹ, σu]: EvalResult = eval_(ρ)(e.σ)(e.e),
                     [tv, ρʺ, κ] : EvalResult = eval_(union([ρ, ρʹ]))(σ)(σu)
               return __result(α, Trace.Match.at(keyP(α, "trace"), tu, tv.trace), tv.val, ρʺ, κ)
            } else
            if (e instanceof Expr.App) {
               const β: Addr = keyP(α, "trace"),
                     [tf, ,]: EvalResult = eval_(ρ)(AST.FunTrie.at(keyP(α, "1"), null))(e.func),
                     f: Value.Value | null = tf.val
               if (f instanceof Value.Closure) {
                  const [tu, ρ2, σʹu]: EvalResult = eval_(ρ)(f.func.σ)(e.arg),
                        // extend(, zip(f.defs.map(def => def.name.str), closeDefs(f.ρ, f.defs))
                        [tv, ρʹ, σv]: EvalResult = eval_(union([f.ρ, ρ2]))(σ)(σʹu)
                  return __result(α, Trace.App.at(β, tf, tu, tv.trace), tv.val, ρʹ, σv)
               } else
               if (f instanceof Value.PrimOp) {
                  // Treat a primitive (which is always unary) as having an anonymous formal parameter.
                  const [tv, , γv]: EvalResult = eval_(ρ)(f.func.σ)(e.arg)                        
                  // TODO: trie for forcing value of primitive type.
                  return __result(α, Trace.PrimApp.at(β, tf, tv), f._apply(tv.val), new Map, null)
               } else {
                  return assert(false, "Not an applicable value.", f)
               }
            }
            return assert(false)
         }
      })
   })
}

__def(closeDefs)
function closeDefs (ρ: Env, defs: AST.RecDefinition[]): Value.Closure[] {
   const closeDef = 
      __defLocal(key(closeDefs, arguments), function closeDef (def: AST.RecDefinition): Value.Closure {
         return Value.Closure.at(key(closeDef, arguments), ρ, defs, def.func)
      })
   return defs.map(closeDef)
}

__def(bindRecDef)
function bindRecDef ([binding, f]: [AST.RecBinding, Value.Closure]): AST.RecBinding {
  const α: Addr = key(bindRecDef, arguments)
  return AST.RecBinding.at(α, binding.def, f)
}

// Return matched pattern and modified environment iff there is a successful match.
// Also see 0.6.4 release notes.
__def(match)
function match (v: Traced, ρ: Env, p: Traced): [Traced, Env] | null {
   const α: Addr = key(match, arguments)
   if (p.name !== null) {
      // variable pattern always succeeds (check whether I need to clone var here)
      assert(p.val === null)
      return [Traced.at(α, v.trace, p.name, v.val), extend(ρ, [[p.name.str, v.val]])]
   } else {
      // otherwise succeed iff constructors match and sub-patterns match sub-values
      const v_: AST.Constr = as(v.val, AST.Constr),
            p_: AST.Constr = as(p.val, AST.Constr)
      if (eq(__nonNull(v_).ctr, p_.ctr)) {
         let matched: boolean = true
         const submatch =
            __defLocal(α, function submatch ([v, p]: [Traced, Traced]): Traced {
               const vρ_opt: [Traced, Env] | null = match(v, ρ, p)
               if (vρ_opt === null) {
                  matched = false
                  return p
               } else {
                  ρ = vρ_opt[1]
                  return vρ_opt[0]
               }
            })
         const ps: Traced[] = zip(v_.args, p_.args).map(submatch)
         if (matched) {
            const v_: AST.Constr = AST.Constr.at(keyP(α, "v_"), p_.ctr, ps)
            return [Traced.at(α, v.trace, null, v_), ρ]
         }
      }
      return null
   }
}

}
