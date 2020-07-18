# frozen_string_literal: true

require_relative 'io_request/version'
require_relative 'io_request/utility/multi_thread'
require_relative 'io_request/utility/with_id'
require_relative 'io_request/utility/with_prog_name'

require_relative 'io_request/authorizer'
require_relative 'io_request/message'
require_relative 'io_request/client'

require 'logger'

# Main module.
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
