# frozen_string_literal: true

module ::DiscourseKanban
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseKanban
    config.autoload_paths << File.join(config.root, "lib")
  end

  def self.card_onebox_template
    path =
      "#{Rails.root}/plugins/discourse-kanban/lib/onebox/templates/discourse_kanban_card.mustache"
    return File.read(path) if Rails.env.development?

    @card_onebox_template ||= File.read(path)
  end

  def self.board_onebox_template
    path =
      "#{Rails.root}/plugins/discourse-kanban/lib/onebox/templates/discourse_kanban_board.mustache"
    return File.read(path) if Rails.env.development?

    @board_onebox_template ||= File.read(path)
  end
end
