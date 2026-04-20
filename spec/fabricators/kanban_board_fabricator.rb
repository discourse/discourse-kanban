# frozen_string_literal: true

Fabricator(:kanban_board, class_name: "DiscourseKanban::Board") do
  name { sequence(:kanban_board_name) { |i| "#{Faker::Company.buzzword.capitalize} Board #{i}" } }
  created_by { Fabricate(:user) }
end
