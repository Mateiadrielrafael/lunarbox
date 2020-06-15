import * as Native from "src/typescript/render"
import { GeometryCache, NodeId, NodeData } from "src/typescript/types/Node"
import { Vec2Like } from "@thi.ng/vectors"

// The initial cache used from purescript
export const emptyGeometryCache = Native.emptyGeometryCache

// Add a new node to the scene
export const loadNode = (cache: GeometryCache) => (id: NodeId) => (
  data: NodeData
) => () => {
  const shape = Native.renderNode(
    (id) => (cache.nodes.get(id)?.output.pos ?? [0, 0]) as Vec2Like,
    data
  )

  cache.nodes.set(id, shape)
}

/**
 * Render  a scene from purescript
 *
 * @param ctx The context to render to
 */
export const renderScene = (ctx: CanvasRenderingContext2D) => (
  cache: GeometryCache
) => () => Native.renderScene(ctx, cache)

// To be able to get contexts from purescript
export const getContext = (canvas: HTMLCanvasElement) => () =>
  canvas.getContext("2d")

// Scale a canvas to its bounding box
export const resizeCanvas = (canvas: HTMLCanvasElement) => () => {
  const { width, height } = canvas.getBoundingClientRect()

  canvas.width = width
  canvas.height = height
}

// Same as the above thing but works with rendering contexts instead
export const resizeContext = (ctx: CanvasRenderingContext2D) =>
  resizeCanvas(ctx.canvas)

// Reexports with a few changed names
export const handleMouseMove = Native.onMouseMove
export const handleMouseUp = Native.onMouseUp
export const handleMouseDown = Native.onMouseDown

// We cannot do
// export * from "../typescript/save"
// because purescript cannot understand it yet
import * as Save from "src/typescript/save"
export const geometryCacheToJson = Save.geometryCacheToJson
export const geometryCacheFromJsonImpl = Save.geometryCacheFromJson
