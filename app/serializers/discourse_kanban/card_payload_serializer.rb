# frozen_string_literal: true

module DiscourseKanban
  class CardPayloadSerializer < ApplicationSerializer
    attributes :id,
               :board_id,
               :column_id,
               :card_type,
               :position,
               :title,
               :notes,
               :tag_ids,
               :tags,
               :topic_id,
               :created_at,
               :updated_at,
               :column_changed_at,
               :recency_at,
               :created_by,
               :assigned_to

    has_one :topic, serializer: CardTopicSerializer, embed: :objects
    has_many :tags, embed: :object, serializer: CardTagSerializer

    def include_topic_id?
      object.topic?
    end

    def include_topic?
      object.topic? && object.topic.present? && topic_visible?
    end

    def include_created_at?
      !object.topic?
    end

    def tag_ids
      return [] unless SiteSetting.tagging_enabled

      object.topic? ? [] : object.tag_ids
    end

    def tags
      object.topic? ? [] : ordered_tags
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

    private

    def ordered_tags
      return [] unless SiteSetting.tagging_enabled

      tags_by_id = @options[:tags_by_id]
      return Card.ordered_tags(object.tag_ids) if tags_by_id.blank?

      object.tag_ids.filter_map { |tag_id| tags_by_id[tag_id] }
    end

    def topic_visible?
      scope.present? && scope.can_see?(object.topic)
    end
  end
end
