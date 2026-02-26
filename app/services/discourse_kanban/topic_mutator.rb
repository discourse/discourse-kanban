# frozen_string_literal: true

module DiscourseKanban
  class TopicMutator
    def self.apply!(topic:, column:, guardian:)
      user = guardian.user
      raise Discourse::InvalidAccess.new unless user
      raise Discourse::InvalidAccess.new unless guardian.can_edit?(topic)

      move_topic_to_category(topic, column, guardian, user)
      move_topic_tags(topic, column, guardian)
      move_topic_assignment(topic, column, user)
      move_topic_status(topic, column, user)
    end

    def self.move_topic_to_category(topic, column, guardian, user)
      return if column.move_to_category_id.blank?

      category = Category.find_by(id: column.move_to_category_id)
      raise Discourse::NotFound.new if category.blank?

      guardian.ensure_can_move_topic_to_category!(category)

      options = {
        bypass_bump: true,
        validate_post: false,
        bypass_rate_limiter: true,
        skip_revision: true,
      }

      topic.first_post.revise(user, { category_id: category.id }, options)
    end

    def self.move_topic_tags(topic, column, guardian)
      return if column.move_to_tag.blank?

      board_tags =
        column.board.columns.filter_map { |c| c.move_to_tag.presence }.uniq - [column.move_to_tag]
      current_tags = topic.tags.map(&:name)
      updated_tags = (current_tags - board_tags + [column.move_to_tag]).uniq

      DiscourseTagging.tag_topic_by_names(topic, guardian, updated_tags)
    end

    def self.move_topic_assignment(topic, column, user)
      return if column.move_to_assigned.blank?
      return unless defined?(::Assigner)

      assigner = ::Assigner.new(topic, user)

      case column.move_to_assigned
      when "*"
        nil
      when "nobody"
        assigner.unassign
        topic
          .posts
          .joins(:assignment)
          .where(assignments: { active: true })
          .find_each { |post| ::Assigner.new(post, user).unassign }
      else
        target = User.find_by(username_lower: column.move_to_assigned.downcase)
        target ||= Group.find_by(name: column.move_to_assigned)
        assigner.assign(target) if target
      end
    end

    def self.move_topic_status(topic, column, user)
      return if column.move_to_status.blank?

      enabled = column.move_to_status == "closed"
      topic.update_status("closed", enabled, user)
    end
  end
end
