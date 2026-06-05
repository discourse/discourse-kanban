# frozen_string_literal: true

module DiscourseKanban
  class ViewCard
    include Service::Base

    params { attribute :id, :integer }

    policy :card_not_already_viewed_today
    model :card
    policy :can_view_card
    step :create_view_history

    private

    def card_not_already_viewed_today(params:, guardian:)
      RateLimiter.new(
        guardian.user,
        "kanban_card_viewed_#{params.id}",
        1,
        24.hours,
        apply_limit_to_staff: true,
      ).performed!(raise_error: false)
    end

    def fetch_card(params:)
      DiscourseKanban::Card.find_by(id: params.id)
    end

    def can_view_card(guardian:, card:)
      guardian.can_view_card?(card)
    end

    def create_view_history(guardian:, card:)
      CardHistory.create!(
        card:,
        acting_user: guardian.user,
        action: CardHistory.actions[:card_viewed],
        board_id: card.board_id,
      )
    end
  end
end
