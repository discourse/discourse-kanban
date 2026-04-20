# frozen_string_literal: true

Fabricator(:kanban_column, class_name: "DiscourseKanban::Column") do
  board { Fabricate(:kanban_board) }
  title { Faker::Lorem.words(number: 2).map(&:capitalize).join(" ") }
  position { sequence(:kanban_column_position) }
end
