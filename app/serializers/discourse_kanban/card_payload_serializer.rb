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
               :topic_id,
               :created_at,
               :created_by,
               :assigned_to

    has_one :topic, serializer: CardTopicSerializer, embed: :objects

    def include_topic_id?
      object.topic?
    end

    def include_topic?
      object.topic? && object.topic.present?
    end

    def include_created_at?
      !object.topic?
    end

    def created_by
      { username: object.created_by.username }
    end

    def include_created_by?
      !object.topic? && object.created_by.present?
    end

    def assigned_to
      case object.assigned_to
      when User
        {
          type: "User",
          username: object.assigned_to.username,
          avatar_template: object.assigned_to.avatar_template,
        }
      when Group
        { type: "Group", name: object.assigned_to.name }
      end
    end

    def include_assigned_to?
      !object.topic? && object.assigned_to.present?
    end
  end
end
