# frozen_string_literal: true

Fabricator(:kanban_board, class_name: "DiscourseKanban::Board") do
  name { sequence(:kanban_board_name) { |i| "#{Faker::Company.buzzword.capitalize} Board #{i}" } }
  created_by { Fabricate(:user) }
  transient :column_names

  after_create do |board, evaluator|
    (evaluator[:column_names] || []).each_with_index do |column_name, index|
      board.columns.create!(title: column_name, position: index)
    end

    AccessControlList.insert_all!(
      board.mandatory_acl_as_expanded_list(DiscourseKanban::PLUGIN_NAME),
    )
  end
end
