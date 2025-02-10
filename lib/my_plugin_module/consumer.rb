require "bunny"

module ::HelloModule
  class Consumer
    def initialize
      @connection = nil
      @channel = nil
      @queue = nil

      create_config_watcher
    end

    def connect
      amqp_connect_string = SiteSetting.amqp_connect_string
      if amqp_connect_string.nil? || amqp_connect_string.empty?
        puts "AMQP连接字符串未配置，无法连接到RabbitMQ"
        return
      end

      if @connection
        stop # 关闭之前的连接
      end

      @connection = Bunny.new(amqp_connect_string)
      @connection.start
      @channel = @connection.create_channel
      @queue = @channel.queue('loklik:ideastudio:community:login.sync.queue', durable: true)
      puts "连接到RabbitMQ成功"

      start_consuming
    rescue => e
      puts "连接到RabbitMQ失败: #{e.message}"
    end

    def start_consuming
      if @queue.nil?
        puts "请先连接RabbitMQ"
        return
      end

      puts "开始消费loklik:ideastudio:community:login.sync.queue队列"
      @queue.subscribe(block: true) do |delivery_info, properties, body|
        process_message(body)
        @channel.ack(delivery_info.delivery_tag)
      end
    end

    def process_message(message)
      puts "收到消息: #{message}"
      ConsumerService.consumer_user_login(message)
    end

    def stop
      puts "关闭RabbitMQ连接"
      @connection.close
    end

    private
    def create_config_watcher
      DiscourseEvent.on(:site_setting_changed) do |setting_name|
        if setting_name == :amqp_connect_string  # 这里的setting_name是Symbol类型
          puts "AMQP连接字符串已更新，重新连接RabbitMQ"
          begin
            connect
          rescue => e
            puts "重新连接RabbitMQ失败: #{e.message}"
          end
        end
      end
    end
  end
end
