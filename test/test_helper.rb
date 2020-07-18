# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'io_request'

IORequest.logger.level = $DEBUG ? Logger::DEBUG : Logger::INFO

require 'minitest/autorun'
