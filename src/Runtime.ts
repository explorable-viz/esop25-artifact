import { Class, assert, className, funName, make, __nonNull } from "./util/Core"
import { PersistentObject } from "./util/Core"

export interface Ctr<T> {
   new (): T
}

export abstract class InternedObject extends PersistentObject {
   eq (that: PersistentObject): boolean {
      return this === that
   }
}

function __blankCopy<T extends Object> (src: T): T {
   const tgt: T = Object.create(src.constructor.prototype)
   for (let x of Object.keys(src)) {
      (tgt as any)[x] = null
   }
   return tgt
}

// Argument tgtState is a "value object" whose identity doesn't matter but whose state represents what we currently 
// know about src. Precondition: the two are upper-bounded; postcondition is that they are equal.
export function __mergeAssign (tgtState: Object, src: VersionedObject): boolean {
   assert(__nonNull(tgtState).constructor === __nonNull(src.constructor))
   const tgtState_: any = tgtState as any,
         src_: any = src as any
   let modified: boolean = false
   Object.keys(tgtState).forEach((k: string): void => {
      const v: any = __merge(tgtState_[k], src_[k])
      if (tgtState_[k] !== v || src_[k] !== v) {
         modified = true
         tgtState_[k] = src_[k] = v
      }
   })
   return modified
}

// Least upper bound of two upper-bounded objects.
export function __merge (tgt: Object, src: Object): Object {
   if (src === null) {
      return tgt
   } else 
   if (tgt === null) {
      return src
   } else
   if (src === tgt) {
      return src
   } else {
      assert(tgt.constructor === src.constructor)
      assert(!(tgt instanceof VersionedObject), "Upper-bounded versioned objects have the same address")
      assert(tgt instanceof InternedObject) // ignore other case for now
      const args: any[] = Object.keys(tgt).map((k: string): any => {
         return __merge((tgt as any)[k], (src as any)[k])
      })
      // Two dubious assumptions, but hard to see another technique:
      // (1) entries are supplied in declaration-order (not guaranteed by language spec)
      // (2) constructor arguments also match declaration-order (easy constraint to violate)
      return make(src.constructor as Class<InternedObject>, ...args)
   }
}   

// A memo key which is sourced externally to the system. (The name "External" exists in the global namespace.)
export class ExternalObject extends InternedObject {
   constructor (
      public id: number
   ) {
      super()
   }

   static make (id: number): ExternalObject {
      return make(ExternalObject, id)
   }
}

// Fresh keys represent inputs to the system.
export const ν: () => ExternalObject =
   (() => {
      let count: number = 0
      return () => {
         return ExternalObject.make(count++)
      }
   })()

export abstract class VersionedObject<K extends PersistentObject = PersistentObject> extends PersistentObject {
   // Initialise these at object creation (not enumerable).
   __history: Map<World, Object> = undefined as any // history records only enumerable fields
   __id: K = undefined as any

   // ES6 only allows constructor calls via "new".
   abstract constructor_ (...args: any[]): void

   eq (that: PersistentObject): boolean {
      return this === that
   }
      // At a given version, enforce "increasing" (LVar) semantics.
   __version (): Object {
      let state: Object | undefined = this.__history.get(__w)
      if (state === undefined) {
         state = __blankCopy(this)
         this.__history.set(__w, state)
      }
      __mergeAssign(state, this)
      return this
   }
}

// Keys must be "memo" objects (interned or persistent).
type InstancesMap = Map<PersistentObject, VersionedObject<PersistentObject>>
const __ctrInstances: Map<Ctr<VersionedObject>, InstancesMap> = new Map

// The (possibly already extant) object uniquely identified by a memo-key. Needs to be initialised afterwards.
export function at<K extends PersistentObject, T extends VersionedObject<K>> (α: K, ctr: Ctr<T>, ...args: any[]): T {
   let instances: InstancesMap | undefined = __ctrInstances.get(ctr)
   if (instances === undefined) {
      instances = new Map
      __ctrInstances.set(ctr, instances)
   }
   let o: VersionedObject<K> | undefined = instances.get(α) as VersionedObject<K>
   if (o === undefined) {
      o = Object.create(ctr.prototype) as T
      // This may massively suck, performance-wise. Define these here rather than on VersionedObject
      // to avoid constructors everywhere.
      Object.defineProperty(o, "__id", {
         value: α,
         enumerable: false
      })
      Object.defineProperty(o, "__history", {
         value: new Map,
         enumerable: false
      })
      instances.set(α, o)
   } else {
      // Initialisation calls __version, which enforces single-assignment, so this additional
      // check strictly unnecessary. However failing now avoids weird ill-formed objects.
      assert(o.constructor === ctr, "Address collision (different constructor).", α, className(o), funName(ctr))
   }
   o.constructor_(...args)
   return o.__version() as T
}

class World {
}

const __w: World = new World()
