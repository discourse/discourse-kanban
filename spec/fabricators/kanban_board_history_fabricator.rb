# frozen_string_literal: true

Fabricator(:kanban_board_history, class_name: "DiscourseKanban::BoardHistory") do
  board { Fabricate(:kanban_board) }
  acting_user { Fabricate(:user) }
  action :board_viewed
end
