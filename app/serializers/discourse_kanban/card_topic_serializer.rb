# frozen_string_literal: true

module DiscourseKanban
  class CardTopicSerializer < ApplicationSerializer
    attributes :id, :title, :slug, :category_id, :tags, :bumped_at, :closed, :image_url

    attribute :last_poster
    attribute :assigned_to_user
    attribute :all_assigned_users

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

    def all_assigned_users
      return @all_assigned_users if defined?(@all_assigned_users)

      assignments = @options[:assignments_by_topic]&.[](object.id)
      if assignments.blank? && defined?(Assignment)
        assignments =
          Assignment.where(topic_id: object.id, active: true, assigned_to_type: "User").includes(
            :assigned_to,
          )
        assignments = nil if assignments.none?
      end

      @all_assigned_users =
        if assignments.present?
          assignments
            .filter_map do |a|
              next unless a.assigned_to.is_a?(User)
              { username: a.assigned_to.username, avatar_template: a.assigned_to.avatar_template }
            end
            .uniq { |u| u[:username] }
        end
    end

    def include_all_assigned_users?
      all_assigned_users.present?
    end
  end
end
