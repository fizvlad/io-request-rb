# frozen_string_literal: true

require_relative '../test_helper'

require 'io_request/connection/ssl_sockets'

class ConnectionSslSocketsTest < Minitest::Test
  def setup
    @cert = File.read File.expand_path('../files/cacert.pem', __dir__)
    @key = File.read File.expand_path('../files/key.pem', __dir__)

    @server = IORequest::SSLSockets::Server.new(certificate: @cert, key: @key) do |data|
      data # Echo
    end
    @server.start
  end

  def teardown
    @server.stop
  end

  def test_simple_message
    @client = IORequest::SSLSockets::Client.new(certificate: @cert, key: @key) do |data|
      data # Echo
    end

    @client.connect

    data = @client.request({ num: 1, string: 'str' })
    assert_equal(1, data[:num])
    assert_equal('str', data[:string])
  end
end
