require "bunny"

module ::HelloModule
  class Consumer
    def initialize
      @connection = nil
      @channel = nil
      @queue = nil

      connect
    end

    def connect
      amqp_connect_string = SiteSetting.amqp_connect_string
      if amqp_connect_string.nil? || amqp_connect_string.empty?
        LoggerHelper.warn("AMQP连接字符串未配置，无法连接到RabbitMQ")
        return
      end

      LoggerHelper.info("准备连接到mq：#{amqp_connect_string}")
      @connection = Bunny.new(amqp_connect_string)
      @connection.start
      @channel = @connection.create_channel
      @queue = @channel.queue('loklik:ideastudio:community:login.sync.queue', durable: true)
      LoggerHelper.info("连接到RabbitMQ成功")

      start_consuming
    rescue => e
      LoggerHelper.warn("连接到RabbitMQ失败: #{e.message}")
    end

    def start_consuming
      if @queue.nil?
        LoggerHelper.info("请先连接RabbitMQ")
        return
      end

      LoggerHelper.info("开始消费loklik:ideastudio:community:login.sync.queue队列")
      @queue.subscribe(block: true) do |delivery_info, properties, body|
        process_message(body)
        @channel.ack(delivery_info.delivery_tag)
      end
    end

    def process_message(message)
      LoggerHelper.info("收到消息：#{message}")
      ConsumerService.consumer_user_login(message)
    end

    def stop
      LoggerHelper.info("关闭RabbitMQ连接")
      # note: 这里关闭会出现超时，先不关闭
      @connection.close
    end

    private
    def create_config_watcher
      DiscourseEvent.on(:site_setting_changed) do |setting_name|
        if setting_name == :amqp_connect_string  # 这里的setting_name是Symbol类型
          begin
            connect
          rescue => e
            LoggerHelper.warn("重新连接RabbitMQ失败: #{e.message}")
          end
        end
      end
    end
  end
end
