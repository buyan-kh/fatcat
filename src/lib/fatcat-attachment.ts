export const EAR_LEFT_BASE = { x: -75, y: -62 } as const
export const EAR_RIGHT_BASE = { x: 75, y: -62 } as const
export const TAIL_BASE = { x: 96, y: 53 } as const

export type Point = { x: number; y: number }

export function rotateAround(point: Point, origin: Point, rotationDeg: number): Point {
  const rad = (rotationDeg * Math.PI) / 180
  const cos = Math.cos(rad)
  const sin = Math.sin(rad)
  const dx = point.x - origin.x
  const dy = point.y - origin.y
  return {
    x: origin.x + dx * cos - dy * sin,
    y: origin.y + dx * sin + dy * cos,
  }
}

export function scaleAround(point: Point, origin: Point, scale: number): Point {
  return {
    x: origin.x + (point.x - origin.x) * scale,
    y: origin.y + (point.y - origin.y) * scale,
  }
}

export function bodyTransform(point: Point, rotationDeg: number, scale: number): Point {
  return rotateAround(scaleAround(point, { x: 0, y: 0 }, scale), { x: 0, y: 0 }, rotationDeg)
}

export function earFollowRotationDelta(bodyRotationDeg: number, delayedRotationDeg: number): number {
  return delayedRotationDeg - bodyRotationDeg
}

export function appendageScaleDelta(bodyScale: number, delayedScale: number): number {
  if (bodyScale === 0) return 1
  return delayedScale / bodyScale
}

export function earBaseAttachmentGap(
  bodyScale: number,
  bodyRotationDeg: number,
  earFollowDeltaDeg: number,
  base: Point,
): number {
  const attached = bodyTransform(base, bodyRotationDeg, bodyScale)
  const localAfterFollow = rotateAround(base, base, earFollowDeltaDeg)
  const actual = bodyTransform(localAfterFollow, bodyRotationDeg, bodyScale)
  return Math.hypot(attached.x - actual.x, attached.y - actual.y)
}

export function tailBaseAttachmentGap(
  bodyScale: number,
  bodyRotationDeg: number,
  tailBaseDeltaDeg: number,
  tailScaleDelta: number,
): number {
  const attached = bodyTransform(TAIL_BASE, bodyRotationDeg, bodyScale)
  const localAfterFollow = rotateAround(
    scaleAround(TAIL_BASE, TAIL_BASE, tailScaleDelta),
    TAIL_BASE,
    tailBaseDeltaDeg,
  )
  const actual = bodyTransform(localAfterFollow, bodyRotationDeg, bodyScale)
  return Math.hypot(attached.x - actual.x, attached.y - actual.y)
}

export function detachedEarGroupGap(
  bodyScale: number,
  bodyRotationDeg: number,
  delayedScale: number,
  delayedRotationDeg: number,
  base: Point,
): number {
  const attached = bodyTransform(base, bodyRotationDeg, bodyScale)
  const detached = bodyTransform(
    rotateAround(scaleAround(base, { x: 0, y: 0 }, delayedScale), { x: 0, y: 0 }, delayedRotationDeg),
    0,
    1,
  )
  return Math.hypot(attached.x - detached.x, attached.y - detached.y)
}
