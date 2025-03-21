# frozen_string_literal: true
require_relative 'consumer'
require_relative 'middleware'

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
        consumer.connect # 第一次启动尝试连接到 RabbitMQ
        consumer.start_consuming # 启动消费者
      end
    end

    # 在这里添加中间件
    initializer 'discourse_jwt_middleware.middleware' do |app|
      app.middleware.use HelloModule::Middleware
    end
  end
end

