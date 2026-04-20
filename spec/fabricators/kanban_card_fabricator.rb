# frozen_string_literal: true

Fabricator(:kanban_card, class_name: "DiscourseKanban::Card") do
  board { |attrs| attrs[:column]&.board || Fabricate(:kanban_board) }
  column { |attrs| Fabricate(:kanban_column, board: attrs[:board]) }
  card_type :floater
  title { Faker::Lorem.sentence(word_count: 10) }
  position { sequence(:kanban_card_position) }
end

Fabricator(:kanban_topic_card, from: :kanban_card) do
  card_type :topic
  title nil
  topic { |attrs| Fabricate(:topic) }
end
