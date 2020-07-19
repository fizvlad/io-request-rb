# frozen_string_literal: true

require_relative '../test_helper'

require 'io_request/connection/ssl_sockets'

class ConnectionSslSocketsTest < Minitest::Test
  def setup
    @cert = File.read File.expand_path('../files/cacert.pem', __dir__)
    @key = File.read File.expand_path('../files/key.pem', __dir__)

    @server = IORequest::SSLSockets::Server.new(certificate: @cert, key: @key) do |data, client|
      assert client.is_a? IORequest::Client
      data # Echo
    end
    @server.start

    @client = IORequest::SSLSockets::Client.new(certificate: @cert, key: @key) do |data|
      data # Echo
    end
    @client.connect
  end

  def teardown
    @client.disconnect
    @server.stop
  end

  def test_client_requests
    data = @client.request({ num: 1, string: 'str' })
    assert_equal(1, data[:num])
    assert_equal('str', data[:string])
  end

  def test_server_requests
    data = @server.clients.first.request({ num: 2, string: 'oi' })
    assert_equal(2, data[:num])
    assert_equal('oi', data[:string])
  end
end
