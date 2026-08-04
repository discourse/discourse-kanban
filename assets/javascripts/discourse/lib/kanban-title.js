export function kanbanTitle(record) {
  return record?.unicode_title || record?.title;
}

export function kanbanColumnTitle(card) {
  return card?.unicode_column_title || card?.column_title;
}

export function kanbanMembershipBoardName(membership) {
  return membership?.unicode_board_name || membership?.board_name;
}
