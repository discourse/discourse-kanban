# frozen_string_literal: true

Fabricator(:kanban_card_history, class_name: "DiscourseKanban::CardHistory") do
  board { |attrs| attrs[:card]&.board || attrs[:board] || Fabricate(:kanban_board) }
  card { |attrs| Fabricate(:kanban_card, board: attrs[:board]) }
  acting_user { Fabricate(:user) }
  action :card_viewed
end
