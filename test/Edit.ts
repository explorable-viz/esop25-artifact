/// <reference path="../node_modules/@types/mocha/index.d.ts" />

import { Edit } from "./util/Core"
import { as } from "../src/util/Core"
import { Cons, Pair, NonEmpty } from "../src/BaseTypes"
import { Expr } from "../src/Expr"
import { open } from "../src/Module"
import { Persistent } from "../src/Value"
import { ν, num, str } from "../src/Versioned"
import { ExplValueCursor, ExprCursor } from "..//src/app/Cursor"

import Trie = Expr.Trie

before((done: MochaDone) => {
   done()
})

describe("edit", () => {
   describe("arithmetic", () => {
      it("ok", () => {
         const e: Expr = open("arithmetic")
         new (class extends Edit {
            setup (here: ExprCursor) {
               here.skipImports()
                   .to(Expr.BinaryApp, "e1")
                   .to(Expr.BinaryApp, "e2")
                   .to(Expr.ConstNum, "val")
                   .setNum(6)
            }

            expect (here: ExplValueCursor) {
               here.isChanged({ val: 49 })
                   .toTerminal()
                   .toBinaryArg1()
                   .isChanged({ val: 7 })
                   .toTerminal()
                   .toBinaryArg2()
                   .isChanged({ val: 6 })
            }
         })(e)
      })
   })

   describe("filter", () => {
      it("ok", () => {
         const e: Expr = open("filter")
         new (class extends Edit {
            setup (here: ExprCursor) {
               here.skipImports()
                   .to(Expr.App, "f")
                   .to(Expr.App, "e")
                   .to(Expr.Fun, "σ")
                   .to(Trie.Var, "κ")
                   .to(Expr.BinaryApp, "e1")
                   .to(Expr.ConstNum, "val")
                   .setNum(3)
            }

            expect (here: ExplValueCursor) {
               here.isNew()
                   .to(Cons, "head")
                   .isUnchanged()
               here.to(Cons, "tail")
                   .isUnchanged()
                   .to(Cons, "tail")
                   .isUnchanged()
            }
         })(e)
      })
   })

   describe("foldr_sumSquares", () => {
      it("ok", () => {
         const e: Expr = open("foldr_sumSquares")
         new (class extends Edit {
            setup (here: ExprCursor) {
               here = here.skipImports()
                   .to(Expr.App, "f")
                   .to(Expr.App, "f")
                   .to(Expr.App, "e")
                   .to(Expr.Fun, "σ")
                   .to(Trie.Constr, "cases")
                   .treeNodeValue()
                   .var_("x")
                   .var_("y") // body of clause 
               here.to(Expr.BinaryApp, "opName")
                   .setStr("/")
               here.splice(Expr.BinaryApp, ["e1", "e2"], ([e1, e2]: Persistent[]): [Expr, Expr] => {
                      const e1ʹ: Expr = Expr.binaryApp(as(e1, Expr.Expr), str("+")(ν()), as(e2, Expr.Expr))(ν()),
                            e2ʹ: Expr = Expr.constNum(num(2)(ν()))(ν())
                      return [e1ʹ, e2ʹ]
                   })
            }

            expect (here: ExplValueCursor) {
            }
         })(e)
      })
   })

   describe("ic2019", () => {
      it("ok", () => {
         const e: Expr = open("ic2019")
         new (class extends Edit {
            setup (here: ExprCursor) {
               here.skipImports()
                   .toDef("f")
                   .to(Expr.RecDef, "σ")
                   .to(Trie.Constr, "cases")
                   .to(NonEmpty, "left") // Cons
                   .treeNodeValue()
                   .var_("x").var_("xs")
                   .constr_splice1(Cons, "head", (e: Expr): Expr => {
                      const eʹ: Expr = Expr.app(Expr.var_(str("sq")(ν()))(ν()), Expr.var_(str("x")(ν()))(ν()))(ν())
                      return Expr.dataExpr(Pair.name, [e, eʹ])(ν())
                   })
            }

            expect (here: ExplValueCursor) {
               here.to(Cons, "head").isNew().to(Pair, "fst").isUnchanged()
               here.to(Cons, "head").to(Pair, "snd").isNew()
               here = here.to(Cons, "tail")
               here.to(Cons, "head").isNew().to(Pair, "fst").isUnchanged()
               here.to(Cons, "head").to(Pair, "snd").isNew()
            }
         })(e)
      })
   })   
})
