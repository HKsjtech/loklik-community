# frozen_string_literal: true
require_relative 'consumer'
module ::HelloModule
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace HelloModule
    config.autoload_paths << File.join(config.root, "lib")
    scheduled_job_dir = "#{config.root}/app/jobs/scheduled"
    config.to_prepare do
      Rails.autoloaders.main.eager_load_dir(scheduled_job_dir) if Dir.exist?(scheduled_job_dir)
      Thread.new do
        consumer = HelloModule::Consumer.new
        consumer.start_consuming
      end
    end
  end
end

