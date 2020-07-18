# frozen_string_literal: true

require 'logger'

module IORequest
  # @return [Logger]
  def self.logger
    @@logger ||= Logger.new( # rubocop:disable Style/ClassVars
      STDOUT,
      formatter: proc do |severity, datetime, progname, msg|
        "[#{datetime}] #{severity} - #{progname}:\t #{msg}\n"
      end
    )
  end

  # @param new_logger [Logger]
  def self.logger=(new_logger)
    @@logger = new_logger # rubocop:disable Style/ClassVars
  end
end
