# frozen_string_literal: true

module ::DiscourseKanban
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseKanban
    config.autoload_paths << File.join(config.root, "lib")
  end
end
