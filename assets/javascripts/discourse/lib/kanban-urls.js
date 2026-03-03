export function kanbanBoardUrl(board) {
  return `/kanban/boards/${board.slug}/${board.id}`;
}

export function kanbanCardUrl(board, cardId) {
  return `${kanbanBoardUrl(board)}/card/${cardId}`;
}
