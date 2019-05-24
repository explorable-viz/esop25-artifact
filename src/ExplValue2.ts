import { List } from "./BaseTypes2"
import { Env } from "./Env2"
import { ExplId } from "./Eval2"
import { Match } from "./Match2"
import { DataValue, Str, Value, _, make } from "./Value2"
import { Versioned, VersionedC, at } from "./Versioned2"

export type Expl = Expl.Expl

export class ExplValue extends DataValue<"ExplValue"> {
   t: Expl = _
   v: Versioned<Value> = _
}

export function explValue (t: Expl, v: Versioned<Value>): ExplValue {
   return make(ExplValue, t, v)
}

export namespace Expl {
   export abstract class Expl extends VersionedC(DataValue)<"Expl"> {
   }

   export class App extends Expl {
      tf: ExplValue = _
      tu: ExplValue = _
      ρᵟ: Env = _                      // from closeDefs, for uneval
      ξ: Match<Versioned<Value>> = _
      tv: ExplValue = _
   }

  export function app (k: ExplId, tf: ExplValue, tu: ExplValue, ρᵟ: Env, ξ: Match<Versioned<Value>>, tv: ExplValue): App {
      return at(k, App, tf, tu, ρᵟ, ξ, tv)
   }

   export class UnaryApp extends Expl {
      tf: ExplValue = _
      tv: ExplValue = _
   }

   export function unaryApp (k: ExplId, tf: ExplValue, tv: ExplValue): UnaryApp {
      return at(k, UnaryApp, tf, tv)
   }

   export class BinaryApp extends Expl {
      tv1: ExplValue = _
      opName: Str = _
      tv2: ExplValue = _
   }

   export function binaryApp (k: ExplId, tv1: ExplValue, opName: Str, tv2: ExplValue): BinaryApp {
      return at(k, BinaryApp, tv1, opName, tv2)
   }

   export abstract class Def extends DataValue<"Expl.Def"> {
   }

   // tv is the computed value, v is the copy of tv.v bound to x.
   export class Let extends Def {
      x: Versioned<Str> = _
      tv: ExplValue = _
      v: Versioned<Value> = _
   }

   export function let_ (x: Versioned<Str>, tv: ExplValue, v: Versioned<Value>): Let {
      return make(Let, x, tv, v)
   }

   // See Let.
   export class Prim extends Def {
      x: Versioned<Str> = _
      v: Value = _ // underlying primitive is not versioned
      vʹ: Versioned<Value> = _
   }

   export function prim (x: Versioned<Str>, v: Value, vʹ: Versioned<Value>): Prim {
      return make(Prim, x, v, vʹ)
   }

   export class LetRec extends Def {
      ρᵟ: Env = _
   }

   export function letRec (ρᵟ: Env): LetRec {
      return make(LetRec, ρᵟ)
   }

   export class Defs extends Expl {
      def̅: List<Def> = _
      tv: ExplValue = _
   }

   export function defs (k: ExplId, def̅: List<Def>, tv: ExplValue): Defs {
      return at(k, Defs, def̅, tv)
   }

   export class Empty extends Expl {
   }

   export function empty (k: ExplId): Empty {
      return at(k, Empty)
   }

   export class MatchAs extends Expl {
      tu: ExplValue = _
      ξ: Match<Versioned<Value>> = _
      tv: ExplValue = _
   }

   export function matchAs (k: ExplId, tu: ExplValue, ξ: Match<Versioned<Value>>, tv: ExplValue): MatchAs {
      return at(k, MatchAs, tu, ξ, tv)
   }

   // v is the resolved value of x
   export class Var extends Expl {
      x: Str = _
      v: Versioned<Value> = _
   }

   export function var_ (k: ExplId, x: Str, v: Versioned<Value>): Var {
      return at(k, Var, x, v)
   }
}
