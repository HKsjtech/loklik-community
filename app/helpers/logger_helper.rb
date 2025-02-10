
class LoggerHelper
  PREFIX = "[loklik-plugin] "

  def self.current_time
    Time.now.strftime("[%Y-%m-%d %H:%M:%S]")  # 格式化时间字符串
  end

  def self.info(message)
    Rails.logger.info("#{PREFIX} #{current_time} #{message}")
  end

  def self.warn(message)
    Rails.logger.warn("#{PREFIX} #{current_time} #{message}")
  end

  def self.error(message)
    Rails.logger.error("#{PREFIX} #{current_time} #{message}")
  end

  # 你可以根据需要添加其他日志级别的方法
end
