require "bunny"

module ::HelloModule
  class Consumer
    def initialize
      # todo: 连接信息处理
      @connection = Bunny.new(
        host: '172.16.130.5',
        port: 5672,
        username: 'admin',
        password: 'P7jNgYfc',
        vhost: 'dev'
      )
      @connection.start
      @channel = @connection.create_channel
      @queue = @channel.queue('loklik:ideastudio:community:login.sync.queue', durable: true)
    end

    def start_consuming
      puts "开始消费loklik:ideastudio:community:login.sync.queue队列"
      @queue.subscribe(block: true) do |delivery_info, properties, body|
        process_message(body)
        @channel.ack(delivery_info.delivery_tag)
      end
    end

    def process_message(message)
      puts "收到消息: #{message}"
      # 在这里处理消息，例如保存到数据库或执行其他操作
      ConsumerService.consumer_user_login(message)
    end

    def stop
      @connection.close
    end
  end
end
