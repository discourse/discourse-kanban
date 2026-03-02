# frozen_string_literal: true

module DiscourseKanban
  class CardPayloadSerializer < ApplicationSerializer
    attributes :id,
               :board_id,
               :column_id,
               :card_type,
               :membership_mode,
               :position,
               :title,
               :notes,
               :labels,
               :due_at

    attribute :topic_id
    attribute :topic
    attribute :updated_at
    attribute :updated_by

    def include_topic_id?
      object.topic?
    end

    def topic
      CardTopicSerializer.new(
        object.topic,
        root: false,
        assignments_by_topic: @options[:assignments_by_topic] || {},
      ).as_json
    end

    def include_topic?
      object.topic? && object.topic.present?
    end

    def include_updated_at?
      !object.topic?
    end

    def updated_by
      { username: object.updated_by.username }
    end

    def include_updated_by?
      !object.topic? && object.updated_by.present?
    end
  end
end
