# frozen_string_literal: true

require_relative '../test_helper'

require 'io_request/connection/ssl_sockets'

class ConnectionSslSocketsTest < Minitest::Test
  def setup
    @cert = File.read File.expand_path('../files/cacert.pem', __dir__)
    @key = File.read File.expand_path('../files/key.pem', __dir__)
    @port = 8000 + rand(1000)

    @server = IORequest::SSLSockets::Server.new(port: @port, certificate: @cert, key: @key) do |data, client|
      assert client.is_a? IORequest::Client
      data # Echo
    end
    @server.start

    @client = IORequest::SSLSockets::Client.new(certificate: @cert, key: @key) do |data|
      data # Echo
    end
    @client.connect('localhost', @port)
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
    assert_equal 1, @server.clients.size
    assert @server.clients.first.open?

    data = @server.clients.first.request({ num: 2, string: 'oi' })
    assert_equal(2, data[:num])
    assert_equal('oi', data[:string])
  end

  def test_clients_count
    @client2 = IORequest::SSLSockets::Client.new(certificate: @cert, key: @key) do |data|
      data # Echo
    end
    @client2.connect('localhost', @port)
    @client2.disconnect
    sleep 1 # NOTE: Give server some time to understand connection was closed
    assert_equal 1, @server.clients.size
  end

  def test_clients_data
    assert @server.data(@server.clients.first).is_a? Hash

    @server.data(@server.clients.first)[:num] = 123
    assert_equal 123, @server.data(@server.clients.first)[:num]
  end
end
