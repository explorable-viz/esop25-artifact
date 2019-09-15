import { AClass, Class, absurd, as, assert } from "../../src/util/Core"
import { Annotation, ann } from "../../src/util/Lattice"
import { Annotated, annotated } from "../../src/Annotated"
import { Cons, List, NonEmpty, Pair } from "../../src/BaseTypes"
import { DataValue, ExplValue } from "../../src/DataValue"
import { Expl } from "../../src/Expl"
import { Expr } from "../../src/Expr"
import { Persistent, Value } from "../../src/Value"

import Def = Expr.Def
import Let = Expr.Let
import LetRec = Expr.LetRec
import Prim = Expr.Prim
import RecDef = Expr.RecDef
import Trie = Expr.Trie

export class ExplCursor implements Annotated<ExplCursor> {
   readonly tv: ExplValue

   constructor (tv: ExplValue) {
      this.tv = tv
   }

   to<T extends DataValue> (C: Class<T>, k: keyof T): ExplCursor {
      return new ExplCursor(Expl.explChild(this.tv.t, as(this.tv.v, DataValue), k))
   }

   at<T extends Value> (C: AClass<T>, f: (o: T) => void): this {
      f(as<Value, T>(this.tv.v, C))
      return this
   }

   assert<T extends Value> (C: AClass<T>, pred: (v: T) => boolean): this {
      return this.at(C, v => assert(pred(v)))
   }

   get __α (): Annotation {
      assert(annotated(this.tv.t))
      return this.tv.t.__α
   }

   needed (): this {
      assert(annotated(this.tv.t) && this.tv.t.__α === ann.top)
      return this
   }

   notNeeded(): this {
      assert(annotated(this.tv.t) && this.tv.t.__α === ann.bot)
      return this
   }

   need (): this {
      if (annotated(this.tv.t)) {
         this.tv.t.__α = ann.top
      } else {
         assert(false)
      }
      return this
   }

   notNeed(): this {
      if (annotated(this.tv.t)) {
         this.tv.t.__α = ann.top
      } else {
         assert(false)
      }
      return this
   }
}

export class Cursor {
   prev: Value[] = []
   v: Value

   constructor (v: Value) {
      this.goto(v)
   }

   goto (v: Value): Cursor {
      this.v = v
      return this
   }

   skipImport (): Cursor {
      return this.to(Expr.Defs, "e") // all "modules" have this form
   }

   skipImports (): Cursor {
      return this.skipImport() // prelude
   }

   // No way to specify only "own" properties statically.
   to<T extends Value> (C: Class<T>, prop: keyof T): Cursor {
      const vʹ: T[keyof T] = as<Persistent, T>(this.v, C)[prop] // TypeScript nonsense
      this.v = vʹ as any as Value
      return this
   }

   static defs (defs: List<Def>): Map<string, Let | Prim | RecDef> {
      const defsʹ: Map<string, Let | Prim | RecDef> = new Map
      for (; Cons.is(defs); defs = defs.tail) {
         const def: Def = defs.head
         if (def instanceof Let || def instanceof Prim) {
            defsʹ.set(def.x.val, def)
         } else
         if (def instanceof LetRec) {
            for (let recDefs: List<RecDef> = def.δ; Cons.is(recDefs); recDefs = recDefs.tail) {
               const recDef: RecDef = recDefs.head
               defsʹ.set(recDef.x.val, recDef)
            }
         } else {
            absurd()
         }
      }
      return defsʹ
   }

   toDef (x: string): Cursor {
      this.to(Expr.Defs, "def̅")
      const defs: Map<string, Let | Prim | RecDef> = Cursor.defs(this.v as List<Def>)
      assert(defs.has(x), `No definition of "${x}" found.`)
      return this.goto(defs.get(x)!)
   }

   at<T extends Value> (C: AClass<T>, f: (o: T) => void): Cursor {
      f(as<Value, T>(this.v, C))
      return this
   }

   assert<T extends Value> (C: AClass<T>, pred: (v: T) => boolean): Cursor {
      return this.at(C, v => assert(pred(v)))
   }

   needed (): Cursor {
      assert(annotated(this.v) && this.v.__α === ann.top)
      return this
   }

   notNeeded (): Cursor {
      assert(annotated(this.v) && this.v.__α === ann.bot)
      return this
   }

   need (): Cursor {
      if (annotated(this.v)) {
         this.v.__α = ann.top
      } else {
         assert(false)
      }
      return this
   }

   notNeed (): Cursor {
      if (annotated(this.v)) {
         this.v.__α = ann.bot
      } else {
         assert(false)
      }
      return this
   }

   push (): Cursor {
      this.prev.push(this.v)
      return this
   }

   pop (): Cursor {
      const v: Value | undefined = this.prev.pop()
      if (v === undefined) {
         return absurd()
      } else {
         this.v = v
      }
      return this
   }

   // Helpers specific to certain datatypes.

   toElem (n: number): Cursor {
      if (n === 0) {
         return this.to(Cons, "head")
      } else {
         this.to(Cons, "tail")
         return this.toElem(n - 1)
      }
   }

   // Not sure what the T parameters are for here...
   constrArg<T extends Value> (ctr: string, n: number): Cursor {
      return this.at(Expr.Constr, e => assert(e.ctr.val === ctr, `${e.ctr.val} !== ${ctr}`))
                 .to(Expr.Constr, "args")
                 .toElem(n)
   }

   nodeValue (): Cursor {
      return this.to(NonEmpty, "t")
                 .to(Pair, "snd")
   }

   var_ (x: string): Cursor {
      return this.assert(Trie.Var, σ => σ.x.val === x)
                 .to(Trie.Var, "κ")      
   }
}
