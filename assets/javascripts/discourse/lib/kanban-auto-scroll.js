const AUTO_SCROLL_EDGE_SIZE = 72;
const AUTO_SCROLL_MAX_SPEED = 10;

export function autoScrollSpeedForPointer(pointerPosition, rect, axis = "y") {
  if (!rect) {
    return 0;
  }

  const startEdge = axis === "x" ? rect.left : rect.top;
  const endEdge = axis === "x" ? rect.right : rect.bottom;

  const startDistance = pointerPosition - startEdge;
  if (startDistance < AUTO_SCROLL_EDGE_SIZE) {
    return -Math.ceil(
      ((AUTO_SCROLL_EDGE_SIZE - Math.max(startDistance, 0)) /
        AUTO_SCROLL_EDGE_SIZE) *
        AUTO_SCROLL_MAX_SPEED
    );
  }

  const endDistance = endEdge - pointerPosition;
  if (endDistance < AUTO_SCROLL_EDGE_SIZE) {
    return Math.ceil(
      ((AUTO_SCROLL_EDGE_SIZE - Math.max(endDistance, 0)) /
        AUTO_SCROLL_EDGE_SIZE) *
        AUTO_SCROLL_MAX_SPEED
    );
  }

  return 0;
}
