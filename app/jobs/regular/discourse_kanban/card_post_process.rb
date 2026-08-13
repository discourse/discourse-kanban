# frozen_string_literal: true

module Jobs
  module DiscourseKanban
    class CardPostProcess < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.discourse_kanban_enabled?

        card_id = args[:card_id]
        title = args[:title]
        return if card_id.blank? || title.blank?

        card = ::DiscourseKanban::Card.find_by(id: card_id)
        return unless current_floater?(card, title)

        inline_onebox_data = ::DiscourseKanban::Action::CardInlineOnebox.call(title:)
        return if card.inline_onebox_data == inline_onebox_data

        updated =
          ::DiscourseKanban::Card.where(id: card.id, card_type: :floater, title:).update_all(
            inline_onebox_data:,
          )
        return if updated.zero?

        card.reload
        payload = ::DiscourseKanban::CardSerializer.new(card, root: false).as_json
        ::DiscourseKanban::Publisher.publish_card_updated!(card.board, payload, client_id: nil)
      end

      private

      def current_floater?(card, title)
        card&.floater? && card.title == title
      end
    end
  end
end
