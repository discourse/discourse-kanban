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
      return nil unless topic_matches?(topic)

      columns.find { |column| column.matches_topic?(topic) }
    end

    def self.topic_matches_query?(topic, query)
      return true if query.blank?

      result =
        TopicQuery.new(
          Discourse.system_user,
          q: query,
          topic_ids: [topic.id],
          per_page: 1,
        ).list_filter

      result.topics.any? { |list_topic| list_topic.id == topic.id }
    rescue StandardError
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
