# frozen_string_literal: true

module PageObjects
  module Components
    class Column < PageObjects::Components::Base
      def initialize(title: nil, id: nil)
        @title = title
        @id = id

        if @title.blank? && @id.blank?
          raise "Column must be initialized with either a title or an id"
        end
      end

      def find_by_title(title)
        find(".discourse-kanban-column__title", text: /#{Regexp.escape(title)}/i).ancestor(
          ".discourse-kanban-column",
        )
      end

      def find_by_id(id)
        find(".discourse-kanban-column[data-column-id='#{id}']")
      end

      def find_column
        if @title
          find_by_title(@title)
        elsif @id
          find_by_id(@id)
        end
      end

      def exists?
        find_column
        true
      end

      def menu
        PageObjects::Components::DMenu.new(
          find_column.find(".discourse-kanban-column__menu-trigger", visible: :all),
        )
      end

      def open_menu
        menu.expand
        self
      end

      def click_delete
        menu.option(".discourse-kanban-column__menu-delete").click
      end
    end
  end
end
