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
               :due_at,
               :topic_id,
               :updated_at,
               :updated_by

    has_one :topic, serializer: CardTopicSerializer

    def include_topic_id?
      object.topic?
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
