# frozen_string_literal: true

require_relative 'test_helper'

require 'socket'
require 'openssl'

$PORT = 8100

# Creating certificate and key for SSL
$KEY = OpenSSL::PKey::RSA.new 2048 # the CA's public/private key
$CERT = OpenSSL::X509::Certificate.new
$CERT.version = 2 # cf. RFC 5280 - to make it a "v3" certificate
$CERT.serial = 1
$CERT.subject = OpenSSL::X509::Name.parse '/DC=org/DC=ruby-lang/CN=Ruby CA'
$CERT.issuer = $CERT.subject # root CA's are "self-signed"
$CERT.public_key = $KEY.public_key
$CERT.not_before = Time.now
$CERT.not_after = $CERT.not_before + 2 * 365 * 24 * 60 * 60 # 2 years validity
ef = OpenSSL::X509::ExtensionFactory.new
ef.subject_certificate = $CERT
ef.issuer_certificate = $CERT
$CERT.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', true))
$CERT.add_extension(ef.create_extension('keyUsage', 'keyCertSign, cRLSign', true))
$CERT.add_extension(ef.create_extension('subjectKeyIdentifier', 'hash', false))
$CERT.add_extension(ef.create_extension('authorityKeyIdentifier', 'keyid:always', false))
$CERT.sign($KEY, OpenSSL::Digest::SHA256.new)

class ClientSslSocketTest < Minitest::Test
  def setup
    $PORT += 1
    puts "Starting test at port #{$PORT}"
    @s = TCPServer.new($PORT)
    c = TCPSocket.new('localhost', $PORT)
    sc = @s.accept

    ctx = OpenSSL::SSL::SSLContext.new
    ctx.cert = $CERT
    ctx.key = $KEY
    ctx.ssl_version = :TLSv1_2

    @c = OpenSSL::SSL::SSLSocket.new(c, ctx)
    @sc = OpenSSL::SSL::SSLSocket.new(sc, ctx)
    connect_thread = Thread.new { @c.connect }
    @sc.accept
    connect_thread.join

    @client_1 = IORequest::Client.new read: @c, write: @c
    @client_2 = IORequest::Client.new read: @sc, write: @sc
  end

  def teardown
    @sc.close
    @c.close
  end

  def test_simple_request
    @client_2.respond do |_request|
      { num: 1, string: 'str' }
    end

    @client_1.request sync: true do |response|
      assert_equal(1, response.data[:num])
      assert_equal('str', response.data[:string])
      assert_nil(response.data[:sync])
      assert_nil(response.data[:timeout])
    end
  end

  def test_intersecting_requests
    total = 10

    @client_2.respond do |request|
      sleep_time = request.data[:sleep_time]
      sleep sleep_time
      { num: request.data[:num] }
    end

    requests = Array.new(total) do |i|
      @client_1.request data: { sleep_time: total - i, num: i } do |response|
        assert_equal(i, response.data[:num])
      end
    end

    requests.each(&:join)
  end
end
