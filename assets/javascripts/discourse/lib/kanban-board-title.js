export function kanbanBoardTitle(board) {
  return board?.unicode_name || board?.name;
}
