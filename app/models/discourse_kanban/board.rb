# frozen_string_literal: true

module DiscourseKanban
  class Board < ActiveRecord::Base
    self.table_name = "discourse_kanban_boards"

    has_many :columns,
             -> { order(:position, :id) },
             class_name: "DiscourseKanban::Column",
             dependent: :destroy,
             inverse_of: :board
    has_many :cards, class_name: "DiscourseKanban::Card", dependent: :destroy, inverse_of: :board

    enum :card_style, { detailed: 0, simple: 1 }, default: :detailed

    validates :name, :slug, presence: true
    validates :slug, uniqueness: true

    validate :validate_group_ids

    before_validation :normalize_slug
    before_validation :normalize_group_ids

    def can_read?(guardian)
      return true if can_write?(guardian)
      return true if public_read?

      user = guardian&.user
      return false if user.blank?

      (effective_read_group_ids & user.group_ids).any?
    end

    def can_write?(guardian)
      user = guardian&.user
      return false if user.blank?
      return true if user.admin?
      return true if created_by_id == user.id

      (allow_write_group_ids & user.group_ids).any?
    end

    def public_read?
      effective_read_group_ids.empty?
    end

    def effective_read_group_ids
      (allow_read_group_ids + allow_write_group_ids).uniq
    end

    def topic_matches?(topic)
      self.class.topic_matches_query?(topic, base_filter_query)
    end

    def first_matching_column(topic)
      all_matching_columns(topic).first
    end

    def all_matching_columns(topic)
      if base_filter_query.present?
        return [] unless topic_matches?(topic)

        lowest_blank = columns.select { |c| c.filter_query.blank? }.min_by(&:id)

        result = []
        columns.each do |column|
          if column.filter_query.blank?
            result << lowest_blank if result.exclude?(lowest_blank)
          elsif column.matches_topic?(topic)
            result << column
          end
        end
        return result
      end

      columns.select do |column|
        next false if column.filter_query.blank?

        self.class.topic_matches_query?(topic, column.filter_query)
      end
    end

    def self.topic_matches_query?(topic, query, matcher_context: nil)
      return false if query.blank?

      cache = matcher_context&.dig(:cache)
      cache_key = [topic.id, query]
      return cache[cache_key] if cache&.key?(cache_key)

      scope =
        matcher_context&.dig(:scope) ||
          TopicQuery.new(Discourse.system_user, limit: false, no_definitions: true).latest_results
      guardian = matcher_context&.dig(:guardian) || Guardian.new(Discourse.system_user)

      matches =
        TopicsFilter
          .new(guardian:, scope:, loaded_topic_users_reference: guardian.authenticated?)
          .filter_from_query_string(query)
          .where(id: topic.id)
          .exists?
      cache[cache_key] = matches if cache
      matches
    rescue StandardError => error
      Rails.logger.warn(
        "DiscourseKanban::Board.topic_matches_query? failed for topic #{topic&.id}, " \
          "query=#{query.inspect}: #{error.class}: #{error.message}",
      )
      cache[cache_key] = false if cache
      false
    end

    private

    def normalize_slug
      source = slug.presence || name
      self.slug = Slug.for(source) if source.present?
    end

    def normalize_group_ids
      self.allow_read_group_ids = normalize_group_array(allow_read_group_ids)
      self.allow_write_group_ids = normalize_group_array(allow_write_group_ids)
    end

    def normalize_group_array(values)
      Array(values).map(&:to_i).uniq.reject(&:zero?)
    end

    def validate_group_ids
      all_group_ids = allow_read_group_ids + allow_write_group_ids
      return if all_group_ids.empty?

      existing_group_ids = Group.where(id: all_group_ids.uniq).pluck(:id)
      missing_group_ids = all_group_ids.uniq - existing_group_ids
      return if missing_group_ids.empty?

      errors.add(
        :base,
        I18n.t("discourse_kanban.errors.unknown_group_ids", group_ids: missing_group_ids.join(",")),
      )
    end
  end
end

# == Schema Information
#
# Table name: discourse_kanban_boards
#
#  id                       :bigint           not null, primary key
#  allow_read_group_ids     :integer          default([]), not null, is an Array
#  allow_write_group_ids    :integer          default([]), not null, is an Array
#  base_filter_query        :text
#  card_style               :integer          default("detailed"), not null
#  name                     :string           not null
#  require_confirmation     :boolean          default(TRUE), not null
#  show_activity_indicators :boolean          default(FALSE), not null
#  show_tags                :boolean          default(FALSE), not null
#  show_topic_thumbnail     :boolean          default(FALSE), not null
#  slug                     :string           not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  created_by_id            :bigint
#  updated_by_id            :bigint
#
# Indexes
#
#  index_discourse_kanban_boards_on_created_by_id  (created_by_id)
#  index_discourse_kanban_boards_on_slug           (slug) UNIQUE
#
