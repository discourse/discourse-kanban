# frozen_string_literal: true

module DiscourseKanban
  class CardOrdering
    GAP_SIZE = 65_536

    def self.place_card!(card, column:, after_card_id: nil, position_first: false)
      card.transaction do
        scope = card.board.cards.with_column.where(column_id: column.id).where.not(id: card.id)

        position = compute_position(scope, after_card_id:, position_first:)

        if position.nil?
          rebalance_column!(card.board, column)
          position = compute_position(scope, after_card_id:, position_first:)
        end

        card.column_id = column.id
        card.position = position
        card.save!
      end
    end

    def self.append_to_column!(card, column)
      next_position =
        card.board.cards.with_column.where(column_id: column.id).maximum(:position).to_i + GAP_SIZE
      card.column_id = column.id
      card.position = next_position
      card
    end

    def self.compute_position(scope, after_card_id:, position_first:)
      if after_card_id.present?
        insert_after_card(scope, after_card_id)
      elsif position_first
        insert_at_beginning(scope)
      else
        insert_at_end(scope)
      end
    end
    private_class_method :compute_position

    def self.insert_after_card(scope, after_card_id)
      anchor = scope.find_by(id: after_card_id)
      return insert_at_end(scope) if anchor.nil?

      neighbor =
        scope
          .where(
            "position > :pos OR (position = :pos AND id > :id)",
            pos: anchor.position,
            id: anchor.id,
          )
          .order(:position, :id)
          .pick(:position)

      if neighbor.nil?
        anchor.position + GAP_SIZE
      else
        gap = neighbor - anchor.position
        return nil if gap <= 1
        anchor.position + gap / 2
      end
    end
    private_class_method :insert_after_card

    def self.insert_at_beginning(scope)
      first_pos = scope.order(:position, :id).pick(:position)
      return 0 if first_pos.nil?
      first_pos - GAP_SIZE
    end
    private_class_method :insert_at_beginning

    def self.insert_at_end(scope)
      max_pos = scope.maximum(:position)
      return 0 if max_pos.nil?
      max_pos + GAP_SIZE
    end
    private_class_method :insert_at_end

    def self.rebalance_column!(board, column)
      card_ids =
        board.cards.with_column.where(column_id: column.id).order(:position, :id).pluck(:id)

      return if card_ids.empty?

      whens = card_ids.map.with_index { |id, i| "WHEN #{id} THEN #{i * GAP_SIZE}" }.join(" ")

      Card.where(id: card_ids).update_all("position = CASE id #{whens} END")
    end
    private_class_method :rebalance_column!
  end
end
