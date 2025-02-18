require "bunny"

module ::HelloModule
  class Consumer
    def initialize
      @connection = nil
      @channel = nil
      @queue_login = nil
      @queue_update = nil

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
      @queue_login = @channel.queue('loklik:ideastudio:community:login.sync.queue', durable: true)
      @queue_update = @channel.queue('loklik:ideastudio:community:userinfo.sync.queue', durable: true)
      LoggerHelper.info("连接到RabbitMQ成功")
    rescue => e
      LoggerHelper.warn("连接到RabbitMQ失败: #{e.message}")
    end

    def start_consuming
      Thread.new { start_consuming_update }
      Thread.new { start_consuming_login }
    end

    def start_consuming_login
      if @queue_login.nil?
        LoggerHelper.info("请先连接RabbitMQ")
        return
      end

      LoggerHelper.info("开始消费loklik:ideastudio:community:login.sync.queue队列")
      @queue_login.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, body|
        LoggerHelper.info("收到login消息：")
        LoggerHelper.info(body)

        ConsumerService.consumer_user_login(body)

        LoggerHelper.info("处理完成")
        @channel.ack(delivery_info.delivery_tag)
        LoggerHelper.info("ack完成")
      end
    rescue => e
      LoggerHelper.error("RabbitMQ消费失败: #{e.message}")
    end

    def start_consuming_update
      if @queue_update.nil?
        LoggerHelper.info("请先连接RabbitMQ")
        return
      end

      LoggerHelper.info("开始消费loklik:ideastudio:community:userinfo.sync.queue队列")
      @queue_update.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, body|
        LoggerHelper.info("收到更新消息：")
        LoggerHelper.info(body)

        ConsumerService.consumer_user_update(body)

        LoggerHelper.info("处理完成")
        @channel.ack(delivery_info.delivery_tag)
        LoggerHelper.info("ack完成")
      end
    rescue => e
      LoggerHelper.error("RabbitMQ消费失败: #{e.message}")
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
