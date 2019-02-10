import { InternedObject, Persistent, VersionedObject, at, make } from "./util/Persistent"
import { List } from "./BaseTypes"
import { Env } from "./Env"
import { FiniteMap } from "./FiniteMap"
import { Runtime } from "./Eval"
import { Expr, Lex } from "./Expr"
import { UnaryOp } from "./Primitive"

export type Value = Value.Value

export namespace Value {
   export abstract class Value extends VersionedObject {
      __subtag: "Value.Value"
   }

   export class Closure extends Value {
      ρ: Env
      σ: Traced.Trie<Traced>
   
      constructor_ (ρ: Env, σ: Traced.Trie<Traced>): void {
         this.ρ = ρ
         this.σ = σ
      }

      static at (α: InternedObject, ρ: Env, σ: Traced.Trie<Traced>): Closure {
         return at(α, Closure, ρ, σ)
      }
   }

   export abstract class Prim extends Value {
      __subsubtag: "Value.Prim"
  }
   
   export class ConstInt extends Prim {
      val: number

      constructor_ (val: number): void {
         this.val = val
      }
   
      static at (α: InternedObject, val: number): ConstInt {
         return at(α, ConstInt, val)
      }

      toString (): string {
         return `${this.val}`
      }
   }
   
   export class ConstStr extends Prim {
      val: string

      constructor_ (val: string): void {
         this.val = val
      }
   
      static at (α: InternedObject, val: string): ConstStr {
         return at(α, ConstStr, val)
      }

      toString (): string {
         return `"${this.val}"`
      }
   }
   
   export class Constr extends Value {
      ctr: Lex.Ctr
      args: List<Traced>

      constructor_ (ctr: Lex.Ctr, args: List<Traced>): void {
         this.ctr = ctr
         this.args = args
      }
   
      static at (α: InternedObject, ctr: Lex.Ctr, args: List<Traced>): Constr {
         return at(α, Constr, ctr, args)
      }
   }

   export class PrimOp extends Value {
      op: UnaryOp

      constructor_ (op: UnaryOp): void {
         this.op = op
      }
   
      static at (α: InternedObject, op: UnaryOp): PrimOp {
         return at(α, PrimOp, op)
      }
   }
}

// Called ExplVal in the formalism.
export class Traced extends InternedObject {
   constructor (
      public t: Trace,
      public v: Value | null
   ) {
      super()
   }

   static make (t: Trace, v: Value | null): Traced {
      return make(Traced, t, v)
   }
}

export type Trace = Traced.Trace

export namespace Traced {
   export type Args<K> = Args.Args<K>

   export namespace Args {
      // n-ary product
      export class Args<K> extends InternedObject {
         __subtag: "Traced.Args"
      }

      // Maps zero arguments to κ.
      export class End<K extends Persistent> extends Args<K> {
         constructor (
            public κ: K
         ) {
            super()
         }

         static is<K extends Persistent> (Π: Args<K>): Π is End<K> {
            return Π instanceof End
         }

         static make<K extends Persistent> (κ: K): End<K> {
            return make(End, κ) as End<K>
         }
      }

      // Maps a single argument to another args trie.
      export class Next<K> extends Args<K> {
         constructor (
            public σ: Trie<Args<K>>
         ) {
            super()
         }

         static is<K> (Π: Args<K>): Π is Next<K> {
            return Π instanceof Next
         }

         static make<K> (σ: Trie<Args<K>>): Next<K> {
            return make(Next, σ)
         }
      }

      export class Top<K extends Persistent> extends Args<K> {
         constructor (
            public κ: K // want fix at null but couldn't make that work with the polymorphism
         ) {
            super()
         }

         static is<K extends Persistent> (Π: Args<K>): Π is Top<K> {
            return Π instanceof Top
         }

         static make<K extends Persistent> (κ: K): Top<K> {
            return make(Top, κ) as Top<K>
         }
      }
   }

   // Tries are interned rather than versioned, as per the formalism (but don't really understand why).
   export type Trie<K> = Trie.Trie<K>

   export type Kont = Traced | Args<any> | Trie<any>

   export namespace Trie {
      export abstract class Trie<K> extends InternedObject {
         __subtag: "Trie.Trie"
      }

      export class Prim<K> extends Trie<K> {
         constructor (
            public κ: K
         ) {
            super()
         }
      }

      export class ConstInt<K extends Persistent> extends Prim<K> {
         static is<K extends Persistent> (σ: Trie<K>): σ is ConstInt<K> {
            return σ instanceof ConstInt
         }

         static make<K extends Persistent> (κ: K): ConstInt<K> {
            return make(ConstInt, κ) as ConstInt<K>
         }
      }

      export class ConstStr<K extends Persistent> extends Prim<K> {
         static is<K extends Persistent> (σ: Trie<K>): σ is ConstStr<K> {
            return σ instanceof ConstStr
         }

         static make<K extends Persistent> (κ: K): ConstStr<K> {
            return make(ConstStr, κ) as ConstStr<K>
         }
      }

      export class Constr<K> extends Trie<K> {
         constructor (
            public cases: FiniteMap<string, Args<K>>
         ) {
            super()
         }

         static is<K> (σ: Trie<K>): σ is Constr<K> {
            return σ instanceof Constr
         }

         static make<K> (cases: FiniteMap<string, Args<K>>): Constr<K> {
            return make(Constr, cases)
         }
      }

      export class Fun<K extends Persistent> extends Trie<K> {
         constructor (
            public κ: K
         ) {
            super()
         }

         static is<K extends Persistent> (σ: Trie<K>): σ is Fun<K> {
            return σ instanceof Fun
         }

         static make<K extends Persistent> (κ: K): Fun<K> {
            return make(Fun, κ) as Fun<K>
         }
      }

      export class Var<K extends Persistent> extends Trie<K> {
         constructor (
            public x: Lex.Var,
            public κ: K
         ) {
            super()
         }

         static is<K extends Persistent> (σ: Trie<K>): σ is Var<K> {
            return σ instanceof Var
         }

         static make<K extends Persistent> (x: Lex.Var, κ: K): Var<K> {
            return make(Var, x, κ) as Var<K>
         }
      }

      // Wanted to fix K at null but that doesn't work with polymorphic code.
      export class Top<K extends Persistent> extends Trie<K> {
         constructor (
            public κ: K
         ) {
            super()
         }

         static is<K extends Persistent> (σ: Trie<K>): σ is Top<K> {
            return σ instanceof Top
         }

         static make<K extends Persistent> (κ: K): Top<K> {
            return make(Top, κ) as Top<K>
         }
      }
   }

   export class TracedMatch<K> extends InternedObject {
      constructor (
         public t: Trace | null, // null iff ξ represents a dead branch
         public ξ: Match<K>
      ) {
         super()
      }

      static make<K> (t: Trace | null, ξ: Match<K>): TracedMatch<K> {
         return make(TracedMatch, t, ξ)
      }
   }

   export type Match<K> = Match.Match<K>

   // A trie which has been matched (executed) to a depth of at least one.
   export namespace Match {
      export type Args<K> = Args.Args<K>

      export namespace Args {
         export class Args<K> extends InternedObject {
            __subtag: "Match.Args"
         }
   
         export class End<K extends Persistent> extends Args<K> {
            constructor (
               public κ: K
            ) {
               super()
            }
   
            static is<K extends Persistent> (Ψ: Args<K>): Ψ is End<K> {
               return Ψ instanceof End
            }
   
            static make<K extends Persistent> (κ: K): End<K> {
               return make(End, κ) as End<K>
            }
         }
   
         export class Next<K> extends Args<K> {
            constructor (
               public tξ: TracedMatch<K>
            ) {
               super()
            }
   
            static is<K> (Ψ: Args<K>): Ψ is Next<K> {
               return Ψ instanceof Next
            }
   
            static make<K> (tξ: TracedMatch<K>): Next<K> {
               return make(Next, tξ)
            }
         }
      }

      export class Match<K> extends InternedObject {
         __subtag: "Match.Match"
      }

      export class Prim<K> extends Match<K> {
         constructor (
            public κ: K
         ) {
            super()
         }
      }

      export class ConstInt<K extends Persistent> extends Prim<K> {
         constructor (
            public val: number,
            κ: K
         ) {
            super(κ)
         }

         static is<K extends Persistent> (ξ: Match<K>): ξ is ConstInt<K> {
            return ξ instanceof ConstInt
         }

         static make<K extends Persistent> (val: number, κ: K): ConstInt<K> {
            return make(ConstInt, val, κ) as ConstInt<K>
         }
      }

      export class ConstStr<K extends Persistent> extends Prim<K> {
         constructor (
            public val: string,
            κ: K
         ) {
            super(κ)
         }

         static is<K extends Persistent> (ξ: Match<K>): ξ is ConstStr<K> {
            return ξ instanceof ConstStr
         }

         static make<K extends Persistent> (val: string, κ: K): ConstStr<K> {
            return make(ConstStr, val, κ) as ConstStr<K>
         }
      }

      // Exactly one branch will be live (i.e. an instanceof Match.Args rather than Trie.Args).
      export class Constr<K> extends Match<K> {
         constructor (
            public cases: FiniteMap<string, Traced.Args<K> | Args<K>> 
         ) {
            super()
         }

         static is<K> (ξ: Match<K>): ξ is Constr<K> {
            return ξ instanceof Constr
         }

         static make<K> (cases: FiniteMap<string, Traced.Args<K> | Args<K>>): Constr<K> {
            return make(Constr, cases)
         }
      }

      export class Fun<K extends Persistent> extends Match<K> {
         constructor (
            public f: Value.Closure | Value.PrimOp,
            public κ: K
         ) {
            super()
         }

         static is<K extends Persistent> (ξ: Match<K>): ξ is Fun<K> {
            return ξ instanceof Fun
         }

         static make<K extends Persistent> (f: Value.Closure | Value.PrimOp, κ: K): Fun<K> {
            return make(Fun, f, κ) as Fun<K>
         }
      }

      export class Var<K extends Persistent> extends Match<K> {
         constructor (
            public x: Lex.Var,
            public v: Value | null,
            public κ: K
         ) {
            super()
         }

         static is<K extends Persistent> (ξ: Match<K>): ξ is Var<K> {
            return ξ instanceof Var
         }

         static make<K extends Persistent> (x: Lex.Var, v: Value | null, κ: K): Var<K> {
            return make(Var, x, v, κ) as Var<K>
         }
      }
   }

   export abstract class Trace extends VersionedObject<Runtime<Expr>> {
      __subtag: "Trace.Trace"
   }
   
   export class App extends Trace {
      func: Traced
      arg: Traced
      body: Trace | null

      constructor_ (func: Traced, arg: Traced, body: Trace | null): void {
         this.func = func
         this.arg = arg
         this.body = body
      }

      static at (k: Runtime<Expr>, func: Traced, arg: Traced, body: Trace | null): App {
         return at(k, App, func, arg, body)
      }
   }

   // Not the same as ⊥ (null); we distinguish information about an absence from the absence of information.
   export class Empty extends Trace {
      constructor_ (): void {
      }

      static at (k: Runtime<Expr>): Empty {
         return at(k, Empty)
      }
   }

   export class Let extends Trace {
      tu: Traced
      σ: Trie.Var<Traced>
      t: Trace | null

      constructor_ (tu: Traced, σ: Trie.Var<Traced>, t: Trace | null): void {
         this.tu = tu
         this.σ = σ
         this.t = t
      }

      static at (k: Runtime<Expr>, tu: Traced, σ: Trie.Var<Traced>, t: Trace | null): Let {
         return at(k, Let, tu, σ, t)
      }
   }

   export class RecDef extends VersionedObject<Runtime<Expr.RecDef>> {
      x: Lex.Var
      tv: Traced

      constructor_ (x: Lex.Var, tv: Traced): void {
         this.x = x
         this.tv = tv
      }
   
      static at (i: Runtime<Expr.RecDef>, x: Lex.Var, tv: Traced): RecDef {
         return at(i, RecDef, x, tv)
      }
   }

   // Continuation here should really be a trace, not a traced value.
   export class LetRec extends Trace {
      δ: List<RecDef>
      tv: Traced
   
      constructor_ (δ: List<RecDef>, tv: Traced): void {
         this.δ = δ
         this.tv = tv
      }

      static at (k: Runtime<Expr>, δ: List<RecDef>, tv: Traced): LetRec {
         return at(k, LetRec, δ, tv)
      }
   }
   
   export class MatchAs extends Trace {
      tu: Traced
      σ: Trie<Traced>
      t: Trace | null

      constructor_ (tu: Traced, σ: Trie<Traced>, t: Trace | null): void {
         this.tu = tu
         this.σ = σ
         this.t = t
      }

      static at (k: Runtime<Expr>, tu: Traced, σ: Trie<Traced>, t: Trace | null): MatchAs {
         return at(k, MatchAs, tu, σ, t)
      }
   }

   export class PrimApp extends Trace {
      tv1: Traced
      opName: Lex.OpName
      tv2: Traced

      constructor_ (tv1: Traced, opName: Lex.OpName, tv2: Traced): void {
         this.tv1 = tv1
         this.opName = opName
         this.tv2 = tv2
      }

      static at (k: Runtime<Expr>, tv1: Traced, opName: Lex.OpName, tv2: Traced): PrimApp {
         return at(k, PrimApp, tv1, opName, tv2)
      }
   }

   export class Var extends Trace {
      x: Lex.Var
      t: Trace | null

      constructor_ (x: Lex.Var, t: Trace | null): void {
         this.x = x
         this.t = t
      }

      static at (k: Runtime<Expr>, x: Lex.Var, t: Trace | null): Var {
         return at(k, Var, x, t)
      }
   }
}
