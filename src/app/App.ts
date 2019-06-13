import { ann } from "../util/Annotated"
import { __nonNull, as } from "../util/Core"
import { emptyEnv, extendEnv } from "../Env"
import { Direction, Eval } from "../Eval"
import { Expl, ExplValue } from "../ExplValue"
import { Expr } from "../Expr"
import { GraphicsElement } from "../Graphics"
import { Value } from "../Value"
import { ν, setallα, str } from "../Versioned"
import { importDefaults, load, parse } from "../../test/util/Core"
import { Cursor } from "../../test/util/Cursor"
import { DataView, DataRenderer } from "./DataRenderer"
import { GraphicsPane3D } from "./GraphicsPane3D"
import { GraphicsRenderer, Slicer, svgNS } from "./GraphicsRenderer"

class App implements Slicer {
   e: Expr                        // entire closed program
   tv: ExplValue                  // chart computed by program
   data_e: Expr                   // expression for data (value bound by first let in user code)
   data_tv: ExplValue
   dataView_e: Expr
   dataView_tv: ExplValue
   dataView: DataView
   dataView2: GraphicsRenderer
   dataCanvas: HTMLCanvasElement
   dataSvg: SVGSVGElement
   dataCtx: CanvasRenderingContext2D
   graphicsView: GraphicsRenderer
   graphicsPane3D: GraphicsPane3D
   graphicsSvg: SVGSVGElement
   direction: Direction

   constructor () {
      this.graphicsSvg = this.createSvg(400, 400)
      this.dataSvg = this.createSvg(400, 400)
      this.dataCanvas = document.createElement("canvas")
      this.dataCtx = __nonNull(this.dataCanvas.getContext("2d"))
      this.graphicsPane3D = new GraphicsPane3D(600, 600)
      this.dataCanvas.style.verticalAlign = "top"
      this.dataCanvas.style.display = "inline-block"
      this.graphicsPane3D.renderer.domElement.style.verticalAlign = "top"
      this.graphicsPane3D.renderer.domElement.style.display = "inline-block"
      document.body.appendChild(this.dataCanvas)
//      document.body.appendChild(this.dataSvg)
      document.body.appendChild(this.graphicsSvg)
      // document.body.appendChild(this.graphicsPane3D.renderer.domElement)
      // this.graphicsPane3D.setCanvas(this.graph      return as(this.tv.v as Value, GraphicsElement)
      this.loadExample()
   }

   createSvg (h: number, w: number): SVGSVGElement {
      const svg: SVGSVGElement = document.createElementNS(svgNS, "svg")
      svg.setAttribute("width", w.toString())
      svg.setAttribute("height", h.toString())
      // TODO: understand how last two numbers below relate to width and height attributes above.
      // See https://vecta.io/blog/guide-to-getting-sharp-and-crisp-svg-images
      svg.setAttribute("viewBox", `-0.5 -0.5 ${w.toString()} ${h.toString()}`)
      // We don't use SVG transform internally, but compute our own transformations (to avoid having non-integer
      // pixel attributes). But to invert the y-axis we use an SVG transform:
      svg.setAttribute("transform", "scale(1,-1)")
      svg.style.verticalAlign = "top"
      svg.style.display = "inline-block"
      return svg
   }

   get graphics (): GraphicsElement {
      return as(this.tv.v as Value, GraphicsElement)
   }

   get dataGraphics(): GraphicsElement {
      return as(this.dataView_tv.v as Value, GraphicsElement)
   }
   
   // "Data" is defined to be the expression bound by the first "let" in user code; must be already in normal form.
   initData (): void {
      let here: Cursor = new Cursor(this.e)
      here.skipImports().toDef("data").to(Expr.Let, "e")
      this.data_e = as(here.v, Expr.Constr)

      here = new Cursor(this.tv)
      here
         .to(ExplValue, "t")
         .to(Expl.Defs, "tv")
         .to(ExplValue, "t")
         .to(Expl.Defs, "tv")
         .to(ExplValue, "t")
         .to(Expl.Defs, "tv")
         .to(ExplValue, "t")
         .to(Expl.Defs, "def̅")
         .toElem(0)
         .assert(Expl.Let, tv => tv.x.val === "data")
         .to(Expl.Let, "tv")
      this.data_tv = as(here.v, ExplValue)
   }

   initViz (): void {
      this.dataView_e = importDefaults(Expr.app(ν(), Expr.var_(ν(), str(ν(), "renderData")), Expr.var_(ν(), str(ν(), "data"))))
      this.dataView_tv = Eval.eval_(extendEnv(emptyEnv(), str(ν(), "data"), this.data_tv.v), this.dataView_e)
   }

   visualise (data_e: Expr): ExplValue {
      setallα(ann.top, this.viz_e)
      Eval.eval_fwd(this.viz_tv)
      return this.viz_tv
   }

   loadExample (): void {
      this.e = parse(load("bar-chart"))
      this.tv = Eval.eval_(emptyEnv(), this.e)
      this.initData()
      this.renderData(this.data_e)
      this.initViz()
      this.visualise(this.data_e)
      this.dataView2 = new GraphicsRenderer(this.dataSvg, this)
      this.graphicsView = new GraphicsRenderer(this.graphicsSvg, this)
      this.resetForFwd()
      this.fwdSlice()
   }

   resetForFwd (): void {
      setallα(ann.top, this.e)
   }

   fwdSlice (): void {
      Eval.eval_fwd(this.tv)
      this.direction = Direction.Fwd
      this.draw()
   }

   resetForBwd (): void {
      setallα(ann.bot, this.e)
      Eval.eval_fwd(this.tv) // to clear all annotations
   }

   bwdSlice (): void {
      Eval.eval_bwd(this.tv)
      this.direction = Direction.Bwd
      this.draw()
   }

   draw (): void {
      this.dataCtx.clearRect(0, 0, this.dataCanvas.width, this.dataCanvas.height)
      this.dataView.draw()
      this.dataView2.render(this.dataGraphics)
      this.graphicsView.render(this.graphics)
      // this.graphicsPane3D.render()
   }

   renderData (data: Expr): void {
      this.dataCanvas.height = 400
      this.dataCanvas.width = 400
      this.dataView = new DataRenderer(this.dataCtx, data, this).view
      this.dataCanvas.addEventListener("mousemove", (e: MouseEvent): void => {
         const rect: ClientRect = this.dataCanvas.getBoundingClientRect()
         this.resetForFwd()
         if (this.dataView.onMouseMove(e.clientX - rect.left, e.clientY - rect.top)) {
            this.fwdSlice()
         }
      })
      this.dataCanvas.height = this.dataView.height + 1 // why extra pixel needed?
      this.dataCanvas.width = this.dataView.width
   }
}

new App()
