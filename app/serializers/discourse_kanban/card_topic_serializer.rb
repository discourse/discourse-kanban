# frozen_string_literal: true

module DiscourseKanban
  class CardTopicSerializer < ApplicationSerializer
    attributes :id,
               :title,
               :slug,
               :category_id,
               :tags,
               :bumped_at,
               :closed,
               :image_url,
               :posts_count

    attribute :last_poster
    attribute :assigned_to_user
    attribute :assigned_to_group
    attribute :all_assigned_users
    attribute :assignments

    def tags
      object.tags.map(&:name)
    end

    def last_poster
      poster = object.last_poster
      { username: poster.username, avatar_template: poster.avatar_template }
    end

    def include_last_poster?
      object.last_poster.present?
    end

    def assigned_to_user
      assigned = object.assignment.assigned_to
      { username: assigned.username, avatar_template: assigned.avatar_template }
    end

    def include_assigned_to_user?
      object.respond_to?(:assignment) && object.assignment&.assigned_to.is_a?(User)
    end

    def assigned_to_group
      group = object.assignment.assigned_to
      { name: group.name }
    end

    def include_assigned_to_group?
      object.respond_to?(:assignment) && object.assignment&.assigned_to.is_a?(Group)
    end

    def all_assigned_users
      @all_assigned_users ||=
        topic_assignments.filter_map { |a| serialize_user(a.assigned_to) }.uniq { |u| u[:username] }
    end

    def include_all_assigned_users?
      all_assigned_users.present?
    end

    def assignments
      topic_assignments.filter_map { |a| serialize_assignment(a) }
    end

    def include_assignments?
      assignments.present?
    end

    private

    def topic_assignments
      @options.fetch(:assignments_by_topic, {}).fetch(object.id, nil) || fallback_assignments
    end

    def fallback_assignments
      return [] unless defined?(Assignment)
      Assignment.where(topic_id: object.id, active: true).includes(:assigned_to)
    end

    def serialize_user(user)
      return unless user.is_a?(User)
      { username: user.username, avatar_template: user.avatar_template }
    end

    def serialize_assignment(assignment)
      assignee = assignment.assigned_to
      result = { target_type: assignment.target_type, target_id: assignment.target_id }

      if assignee.is_a?(User)
        result[:username] = assignee.username
        result[:avatar_template] = assignee.avatar_template
      elsif assignee.is_a?(Group)
        result[:group_name] = assignee.name
      end

      result[:post_number] = assignment.target&.post_number if assignment.target_type == "Post"

      result
    end
  end
end
