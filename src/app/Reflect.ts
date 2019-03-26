import { Annotation, Annotated, ann } from "../util/Annotated"
import { Class, __check, __nonNull, absurd, as, assert } from "../util/Core"
import { Persistent, PersistentObject, make } from "../util/Persistent"
import { at } from "../util/Versioned"
import { Cons, List, Nil } from "../BaseTypes"
import { arity } from "../DataType"
import { ExplVal, Value } from "../ExplVal"
import { Point, Rect } from "../Graphics"

// Reflected versions of primitive constants; should be able to switch to a compiler and use these directly.
// Can't extend built-in classes because they require initialisation at construction-time.

export class AnnBoolean extends Annotated implements PersistentObject {
   b: boolean

   constructor_ (α: Annotation, b: boolean) {
      this.α = α
      this.b = b
   }
}

export class AnnNumber extends Annotated implements PersistentObject {
   n: number

   constructor_ (α: Annotation, n: number) {
      this.α = α
      this.n = n
   }
}

export class AnnString extends Annotated implements PersistentObject {
   str: string

   constructor_ (α: Annotation, str: string) {
      this.α = α
      this.str = str
   }
}

// intermediate value required to stop TS getting confused:
const classFor_: [string, Class<PersistentObject>][] =
   [["Cons", Cons],
    ["Nil", Nil],
    ["Point", Point],
    ["Rect", Rect]],
   classFor: Map<string, Class<PersistentObject>> = new Map(classFor_)

// TODO: use function objects themselves to partition memo keys, as per lambdacalc-old?
class Reflect implements PersistentObject {
   v: Value

   constructor_ (v: Value) {
      this.v = v
   }

   static make (v: Value): Reflect {
      return make(Reflect, v)
   }
}

export function reflect (v: Value): Persistent { 
   if (v instanceof Value.ConstInt) {
      const vʹ: Number = new Number(v.val.valueOf())
      ; (vʹ as any as Annotated).α = ann.meet(__nonNull((v.val as any as Annotated).α), v.α)
      return vʹ
   } else
   if (v instanceof Value.ConstStr) {
      return (v.val as any as Annotated).α = v.α
   } else
   if (v instanceof Value.Constr) {
      const ctr: string = __check(v.ctr.str, it => classFor.has(it)),
            args: Persistent[] = []
      for (let tvs: List<ExplVal> = v.args; Cons.is(tvs);) {
         args.push(reflect(tvs.head.v))
         tvs = tvs.tail
      }
      assert(args.length === arity(ctr))
      // α doesn't appear as argument of user-level data types; sanity-check that reflective counterpart expects it
      return as(at(Reflect.make(v), classFor.get(ctr)!, v.α, ...args), Annotated)
   } else {
      return absurd()
   }
}
