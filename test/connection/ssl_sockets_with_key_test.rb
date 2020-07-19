# frozen_string_literal: true

require_relative '../test_helper'

require 'io_request/connection/ssl_sockets'

class ConnectionSslSocketsWithKeyTest < Minitest::Test
  def setup
    @cert = File.read File.expand_path('../files/cacert.pem', __dir__)
    @key = File.read File.expand_path('../files/key.pem', __dir__)
    @port = 8000 + rand(1000)

    @server = IORequest::SSLSockets::Server.new(
      port: @port,
      certificate: @cert,
      key: @key,
      authorizer: IORequest::Authorizer.by_secret_key('secret key')
    ) do |data, client|
      assert client.is_a? IORequest::Client
      data # Echo
    end
    @server.start

    @client = IORequest::SSLSockets::Client.new(
      certificate: @cert,
      key: @key,
      authorizer: IORequest::Authorizer.by_secret_key('secret key')
    ) do |data|
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

  def test_unauthorized
    @client2 = IORequest::SSLSockets::Client.new(
      certificate: @cert,
      key: @key,
      authorizer: IORequest::Authorizer.by_secret_key('a')
    ) do |data|
      data # Echo
    end
    @client2.connect('localhost', @port)

    refute @client2.connected?

    @client3 = IORequest::SSLSockets::Client.new(
      certificate: @cert,
      key: @key,
      authorizer: IORequest::Authorizer.by_secret_key('secret key')
    ) do |data|
      data # Echo
    end
    @client3.connect('localhost', @port)

    assert @client3.connected?
  end
end
