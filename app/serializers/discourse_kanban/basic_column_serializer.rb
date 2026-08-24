# frozen_string_literal: true

module DiscourseKanban
  class BasicColumnSerializer < ApplicationSerializer
    attributes :id, :unicode_title, :icon, :color
  end
end
