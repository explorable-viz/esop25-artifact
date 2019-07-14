import { absurd } from "./util/Core"
import { DataValue } from "./DataValue"
import { Str, Value, _, make } from "./Value"
import { Annotated } from "./Versioned"

// Idiom is to permit instance methods on reflected datatypes, but not have them use polymorphism.

// Environments are snoc lists.
export abstract class Env extends DataValue<"Env"> {
   get (k: Annotated<Str>): Annotated<Value> | undefined {
      if (this instanceof EmptyEnv) {
         return undefined
      } else
      if (this instanceof ExtendEnv) {
         if (this.k.val === k.val) {
            return this.v
         } else {
            return this.ρ.get(k)
         }
      } else {
         return absurd()
      }
   }
   
   has (k: Annotated<Str>): boolean {
      return this.get(k) !== undefined
   }

   static singleton (k: Annotated<Str>, v: Annotated<Value>): ExtendEnv {
      return extendEnv(emptyEnv(), k, v)
   }
   
   concat (ρ: Env): Env {
      if (ρ instanceof EmptyEnv) {
         return this
      } else
      if (ρ instanceof ExtendEnv) {
         return extendEnv(this.concat(ρ.ρ), ρ.k, ρ.v)
      } else {
         return absurd()
      }
   }
}

export class EmptyEnv extends Env {
}

export function emptyEnv (): EmptyEnv {
   return make(EmptyEnv)
}

export class ExtendEnv extends Env {
   ρ: Env = _
   k: Annotated<Str> = _
   v: Annotated<Value> = _
}

export function extendEnv (ρ: Env, k: Annotated<Str>, v: Annotated<Value>): ExtendEnv {
   return make(ExtendEnv, ρ, k, v)
}
