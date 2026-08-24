# frozen_string_literal: true

module DiscourseKanban
  class BasicBoardSerializer < ApplicationSerializer
    attributes :id, :unicode_name, :slug, :columns

    def columns
      object.columns.map { |column| BasicColumnSerializer.new(column, root: false, scope:).as_json }
    end
  end
end
