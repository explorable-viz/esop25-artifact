import { as, assert } from "./util/Core"
import { Annotated, asAnnotated, annotatedAt, num, str } from "./Annotated"
import { Bool, true_, false_ } from "./BaseTypes"
import { Num, PrimOpTag, PrimValue, Str, _, Value } from "./Value"
import { ν } from "./Versioned"

type Unary<T, V> = (x: T) => Annotated<V>
type Binary<T, U, V> = (x: T, y: U) => Annotated<V>

// In the following two classes, we store the operation without generic type parameters, as fields can't
// have polymorphic type. Then access the operation via a method and reinstate the polymorphism via a cast.

export class PrimOp<Tag extends PrimOpTag> extends Value<Tag> {
   name: string = _
}

export class UnaryOp extends PrimOp<"UnaryOp"> {
   op: Unary<PrimValue, Value> = _
}

export class BinaryOp extends PrimOp<"BinaryOp"> {
   op: Binary<PrimValue, PrimValue, Value> = _
}

const ceiling = (x: Num): Annotated<Num> => num(Math.ceil(x.val))
// Used to take arbitrary value as additional argument, but now primitives have primitive arguments.
const error = (message: Str): Annotated<Value> => assert(false, "LambdaCalc error:\n" + message.val)
const floor = (x: Num): Annotated<Num> => num(Math.floor(x.val))
const log = (x: Num): Annotated<Num> => num(Math.log(as(x, Num).val))
const numToStr = (x: Num): Annotated<Str> => str(x.val.toString())
const trace = (v: Num | Str): Annotated<Value> => { console.log(v); return asAnnotated(v) }
// No longer support overloaded functions, since the pattern-matching semantics is non-trivial; might require typecase.
// If we want integer division, apparently ~~(x / y) will round in the right direction.
const div = (x: Num, y: Num): Annotated<Num> => num(as(x, Num).val / as(y, Num).val)
const concat = (x: Str, y: Str): Annotated<Str> => str(as(x, Str).val + as(y, Str).val)
const equalInt = (x: Num, y: Num): Annotated<Bool> => as(x, Num).val === as(y, Num).val ? true_() : false_()
const equalStr = (x: Str, y: Str): Annotated<Bool> => as(x, Str).val === as(y, Str).val ? true_() : false_()
const greaterEqInt = (x: Num, y: Num): Annotated<Bool> => as(x, Num).val >= as(y, Num).val ? true_() : false_()
// String comparison delegates to central implementation for consistency.
const greaterEqStr = (x: Str, y: Str): Annotated<Bool> => as(x, Str).geq(as(y, Str)) ? true_() : false_()
const greaterInt = (x: Num, y: Num): Annotated<Bool> => as(x, Num).val > as(y, Num).val ? true_() : false_()
const lessEqInt = (x: Num, y: Num): Annotated<Bool> => as(x, Num).val <= as(y, Num).val ? true_() : false_()
const lessEqStr = (x: Str, y: Str): Annotated<Bool> => as(x, Str).leq(as(y, Str)) ? true_() : false_()
const lessInt = (x: Num, y: Num): Annotated<Bool> => as(x, Num).val < as(y, Num).val ? true_() : false_()
const minus = (x: Num, y: Num): Annotated<Num> => num(as(x, Num).val - as(y, Num).val)
const plus = (x: Num, y: Num): Annotated<Num> => num(as(x, Num).val + as(y, Num).val)
const pow = (x: Num, y: Num): Annotated<Num> => num(as(x, Num).val ** as(y, Num).val)
const times = (x: Num, y: Num): Annotated<Num> => num(as(x, Num).val * as(y, Num).val)

// Convenience methods for building the maps. Export to allow other modules to provide operations.
export function unary_<T extends PrimValue, V extends Value> (op: Unary<T, V>): Annotated<UnaryOp> {
   return annotatedAt(ν(), UnaryOp, op.name, op)
}

export function binary_<T extends PrimValue, U extends PrimValue, V extends Value> (op: Binary<T, U, V>): Annotated<BinaryOp> {
   return annotatedAt(ν(), BinaryOp, op.name, op)
}

// Primitives with identifiers as names are unary and first-class.
export const unaryOps: Map<string, Annotated<UnaryOp>> = new Map([
   [ceiling.name, unary_(ceiling)],
   [error.name, unary_(error)],
   [floor.name, unary_(floor)],
   [log.name, unary_(log)],
   [numToStr.name, unary_(numToStr)],
   [trace.name, unary_(trace)]
])
   
export const binaryOps: Map<string, Annotated<BinaryOp>> = new Map([
   ["-", binary_(minus)],
   ["+", binary_(plus)],
   ["*", binary_(times)],
   ["**", binary_(pow)],
   ["/", binary_(div)],
   ["==", binary_(equalInt)],
   ["===", binary_(equalStr)],
   [">", binary_(greaterInt)],
   [">=", binary_(greaterEqInt)],
   [">==", binary_(greaterEqStr)],
   ["<", binary_(lessInt)],
   ["<=", binary_(lessEqInt)],
   ["<==", binary_(lessEqStr)],
   ["++", binary_(concat)]
])
