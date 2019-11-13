require "logger"

module IORequest
  # @!group Logger

  # Default logger.
  @@logger = Logger.new($LOG_FILE || STDOUT,
    formatter: Proc.new do |severity, datetime, progname, msg|
      "[#{datetime}] #{severity} - #{progname}:\t #{msg}\n"
    end
  )
  @@logger.level = $DEBUG ? Logger::DEBUG : Logger::INFO

  # Setup new logger.
  #
  # @param logger [Logger, nil]
  def self.logger=(logger)
    @@logger = logger
  end

  # Access current logger.
  #
  # @return [Logger, nil]
  def self.logger
    @@logger
  end

  # Log message.
  def self.log(severity, message = nil, progname = nil)
    @@logger.log(severity, message, progname) if @@logger
  end

  # Log warning message.
  def self.warn(message = nil, progname = nil)
    @@logger.log(Logger::WARN, message, progname)
  end

  # Log info message.
  def self.info(message = nil, progname = nil)
    @@logger.log(Logger::INFO, message, progname)
  end

  # Log debug message.
  def self.debug(message = nil, progname = nil)
    @@logger.log(Logger::DEBUG, message, progname)
  end

  # @!endgroup
end
