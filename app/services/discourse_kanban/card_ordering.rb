# frozen_string_literal: true

module DiscourseKanban
  class CardOrdering
    def self.place_card!(card, column:, after_card_id: nil)
      card.transaction do
        siblings =
          card.board.cards.with_column.where(column_id: column.id).where.not(id: card.id).ordered.to_a

        insert_at = siblings.length
        if after_card_id.present?
          after_index = siblings.index { |sibling| sibling.id == after_card_id.to_i }
          insert_at = after_index + 1 if after_index
        end

        siblings.insert(insert_at, card)

        siblings.each_with_index do |ordered_card, index|
          ordered_card.column_id = column.id
          ordered_card.position = index
          ordered_card.save! if ordered_card.changed?
        end
      end
    end

    def self.append_to_column!(card, column)
      next_position = card.board.cards.with_column.where(column_id: column.id).maximum(:position).to_i + 1
      card.column_id = column.id
      card.position = next_position
      card
    end
  end
end
