import { Annotated, Annotation, ann } from "./util/Annotated"
import { as } from "./util/Core"
import { Persistent, PersistentObject, make } from "./util/Persistent"
import { List } from "./BaseTypes"

// Reflected versions of primitive constants; should be able to switch to a compiler and use these directly.
// Can't extend built-in classes because they require initialisation at construction-time.

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

// Basic graphical datatypes.

export class Rect extends Annotated {
   width: AnnNumber
   height: AnnNumber

   constructor_ (α: Annotation, width: AnnNumber, height: AnnNumber): void {
      this.α = α
      this.width = as(width, AnnNumber)
      this.height = as(height, AnnNumber)
   }
}

export function rect (width: AnnNumber, height: AnnNumber): Rect {
   return make(Rect, ann.bot, width, height)
}

export class Point extends Annotated {
   x: AnnNumber
   y: AnnNumber

   constructor_ (α: Annotation, x: AnnNumber, y: AnnNumber): void {
      this.α = α
      this.x = as(x, AnnNumber)
      this.y = as(y, AnnNumber)
   }
}

export function point (x: AnnNumber, y: AnnNumber): Point {
   return make(Point, ann.bot, x, y)
}

export abstract class GraphicsElement extends Annotated {
   abstract constructor_ (...v̅: Persistent[]): void
}

export class Graphic extends GraphicsElement {
   elems: List<GraphicsElement>

   constructor_ (α: Annotation, elems: List<GraphicsElement>): void {
      this.α = α
      this.elems = as(elems, List)
   }
}

export class PathStroke extends GraphicsElement {
   points: List<Point>

   constructor_ (α: Annotation, points: List<Point>): void {
      this.α = α
      this.points = points
   }
}

// TODO: generalise to any (closed) path.
export class RectFill extends GraphicsElement {
   points: List<Point>

   constructor_ (α: Annotation, points: List<Point>): void {
      this.α = α
      this.points = points
   }
}

export class Scale extends GraphicsElement {
   x: AnnNumber
   y: AnnNumber
   elem: GraphicsElement

   constructor_ (α: Annotation, x: AnnNumber, y: AnnNumber, elem: GraphicsElement): void {
      this.α = α
      this.x = x
      this.y = y
      this.elem = elem
   }
}

export class Translate extends GraphicsElement {
   x: AnnNumber
   y: AnnNumber
   elem: GraphicsElement

   constructor_ (α: Annotation, x: AnnNumber, y: AnnNumber, elem: GraphicsElement): void {
      this.α = α
      this.x = x
      this.y = y
      this.elem = elem
   }
}

// Swaps x and y. Could subsume by a more general notion of reflection.
export class Transpose extends GraphicsElement {
   elem: GraphicsElement

   constructor_ (α: Annotation, elem: GraphicsElement): void {
      this.α = α
      this.elem = elem
   }
}
