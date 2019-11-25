import { __nonNull, absurd } from "./util/Core"
import { Annotation, bool_ } from "./util/Lattice"
import { ExplValue, DataValue } from "./DataValue"
import { __deltas } from "./Delta"
import { Expl } from "./Expl"
import { Expr } from "./Expr"
import { Persistent, Value, _ } from "./Value"

export type Annotated = Expr.SyntaxNode | ExplValue 

export function annotated (v: Value): v is Annotated {
   return v instanceof Expr.SyntaxNode || v instanceof ExplValue
}

export function isα (v: Annotated): Annotation {
   return __annotations.is(v)
}

// Currently no deltas are associated with annotations.
export function setα<T extends Annotated> (α: Annotation, v: T): void {
   __annotations.set(v, α)
}

export function setjoinα (α: Annotation, v: Annotated): void {
   setα(bool_.join(α, isα(v)), v)
}

export function setmeetα (α: Annotation, v: Annotated): void {
   setα(bool_.meet(α, isα(v)), v)
}

export enum Direction { Fwd, Bwd }

export class Annotations {
   ann: Set<Annotated> = new Set() // unavailable nodes (fwd) or needed nodes (bwd)
   direction: Direction = Direction.Fwd

   // Whether v is needed (going backward) or available (going forward).
   is (v: Annotated): Annotation {
      if (this.direction === Direction.Fwd) {
         return bool_.negate(this.ann.has(v))
      } else {
         return this.ann.has(v)
      }
   }
   
   // Going forward, annotation updates must be decreasing; going backward, increasing. This is because 
   // forward slicing propagates non-availability, whereas backward slicing propagates demand.
   set (v: Annotated, α: Annotation): void {
      const current: Annotation = this.is(v)
      if (this.direction === Direction.Fwd && α < current ||
          this.direction === Direction.Bwd && α > current) {
         this.ann.add(v)
      } else
      if (this.direction === Direction.Fwd && α > current ||
         this.direction === Direction.Bwd && α < current) {
         absurd(`Incompatible update of annotation from ${current} to ${α}.`, current, α)
      } else {
         // idempotent
      }
   }

   reset (direction: Direction): void {
      this.direction = direction
      this.ann.clear()
   }

   restrictTo (v: Value): void {
      const ann: Set<Annotated> = new Set()
      this.restrictTo_aux(v, ann)
      this.ann = ann
   }

   restrictTo_aux (v: Value, ann: Set<Annotated>): void {
      if (this.ann.has(v as Annotated)) { // cast is a bit cheeky
         ann.add(v as Annotated)
      }
      v.__children.forEach((v: Persistent): void => {
         if (v instanceof Value) {
            this.restrictTo_aux(v, ann)
         }
      })
   }

   restrictTo2 (tv: ExplValue): void {
      const ann: Set<Annotated> = new Set()
      this.restrictTo2_aux(tv, ann)
      this.ann = ann
   }

   restrictTo2_aux (tv: ExplValue, ann: Set<Annotated>): void {
      if (this.ann.has(tv)) {
         ann.add(tv)
      }
      if (tv.v instanceof DataValue) {
         Expl.explChildren(tv.t, tv.v).forEach((tv: ExplValue): void => {
            this.restrictTo2_aux(tv, ann)
         })
      }
   }
}

export const __annotations = new Annotations()
