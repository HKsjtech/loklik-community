require "bunny"

module ::HelloModule
  class Consumer
    def initialize
      @connection = Bunny.new(
        host: '172.16.130.5',
        port: 5672,
        username: 'admin',
        password: 'P7jNgYfc',
        vhost: '/'
      )
      @connection.start
      @channel = @connection.create_channel
      @queue = @channel.queue('loklik:ideastudio:community:login.sync.queue', durable: true)
    end

    def start_consuming
      puts "Waiting for messages in #{@queue.name}. To exit press CTRL+C"
      @queue.subscribe(block: true) do |delivery_info, properties, body|
        process_message(body)
      end
    end

    def process_message(message)
      puts "收到消息: #{message}"
      # 在这里处理消息，例如保存到数据库或执行其他操作
      # todo: ack
      ConsumerService.consumer_user_login(message)
    end

    def stop
      @connection.close
    end
  end
end
