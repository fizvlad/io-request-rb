# frozen_string_literal: true

require_relative 'io_request/version'
require_relative 'io_request/utility/with_prog_name'
require_relative 'io_request/utility/multi_thread'

require_relative 'io_request/client'

# Main module.
module IORequest
  # @return [Logger]
  def self.logger
    @@logger ||= Logger.new
  end
  # @param new_logger [Logger]
  def self.logger=(new_logger)
    @@logger =new_logger
  end
end
