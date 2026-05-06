# frozen_string_literal: true

module ::DiscourseKanban
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseKanban
    config.autoload_paths << File.join(config.root, "lib")
  end

  def self.card_onebox_template
    @card_onebox_template ||=
      begin
        path =
          "#{Rails.root}/plugins/discourse-kanban/lib/onebox/templates/discourse_kanban_card.mustache"
        File.read(path)
      end
  end

  def self.board_onebox_template
    @board_onebox_template ||=
      begin
        path =
          "#{Rails.root}/plugins/discourse-kanban/lib/onebox/templates/discourse_kanban_board.mustache"
        File.read(path)
      end
  end
end
