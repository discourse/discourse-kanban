# frozen_string_literal: true

module DiscourseKanban
  class TopicBoardMemberships
    include Service::Base

    options { attribute :topics }

    model :cards_map, optional: true

    private

    def fetch_cards_map(options:, guardian:)
      Action::BuildTopicBoardMembershipsMap.call(topics: options.topics, guardian:)
    end
  end
end
