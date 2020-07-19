# frozen_string_literal: true

# Main module.
module IORequest
  # Client received message of zero size.
  class ZeroSizeMessageError < RuntimeError; end

  # Authorization failed.
  class AuthorizationFailureError < RuntimeError; end
end

require_relative 'io_request/version'
require_relative 'io_request/logging'
require_relative 'io_request/utility/multi_thread'
require_relative 'io_request/utility/with_id'
require_relative 'io_request/utility/with_prog_name'

require_relative 'io_request/authorizer'
require_relative 'io_request/message'
require_relative 'io_request/client'
