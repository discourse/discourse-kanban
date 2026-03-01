# frozen_string_literal: true

module DiscourseKanban
  class CardPayloadSerializer
    def self.serialize(card, assignments_by_topic: {})
      payload = {
        id: card.id,
        board_id: card.board_id,
        column_id: card.column_id,
        card_type: card.card_type,
        membership_mode: card.membership_mode,
        position: card.position,
        title: card.title,
        notes: card.notes,
        labels: card.labels,
        due_at: card.due_at,
      }

      if card.topic?
        payload[:topic_id] = card.topic_id
        payload[:topic] = serialize_topic(card.topic, assignments_by_topic:) if card.topic
      else
        payload[:updated_at] = card.updated_at
        payload[:updated_by] = { username: card.updated_by.username } if card.updated_by
      end

      payload
    end

    def self.serialize_topic(topic, assignments_by_topic: {})
      data = {
        id: topic.id,
        title: topic.title,
        slug: topic.slug,
        category_id: topic.category_id,
        tags: topic.tags.map(&:name),
        bumped_at: topic.bumped_at,
        closed: topic.closed,
        image_url: topic.image_url,
      }

      last_poster = topic.last_poster
      if last_poster
        data[:last_poster] = {
          username: last_poster.username,
          avatar_template: last_poster.avatar_template,
        }
      end

      if topic.respond_to?(:assignment) && topic.assignment&.assigned_to.is_a?(User)
        assigned = topic.assignment.assigned_to
        data[:assigned_to_user] = {
          username: assigned.username,
          avatar_template: assigned.avatar_template,
        }
      end

      all_assignments = assignments_by_topic[topic.id]
      if all_assignments.blank? && defined?(Assignment)
        all_assignments =
          Assignment.where(topic_id: topic.id, active: true, assigned_to_type: "User").includes(
            :assigned_to,
          )
        all_assignments = nil if all_assignments.none?
      end

      if all_assignments.present?
        data[:all_assigned_users] = all_assignments
          .filter_map do |a|
            next unless a.assigned_to.is_a?(User)
            { username: a.assigned_to.username, avatar_template: a.assigned_to.avatar_template }
          end
          .uniq { |u| u[:username] }
      end

      data
    end
    private_class_method :serialize_topic
  end
end
