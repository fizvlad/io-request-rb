# frozen_string_literal: true

require_relative 'test_helper'

class AuthorizerBySecretKeyTest < Minitest::Test
  def setup
    @r1, @w1 = IO.pipe
    @r2, @w2 = IO.pipe

    @client1 = IORequest::Client.new(authorizer: IORequest::Authorizer.by_secret_key('secret_key'))
    @client1.respond do |data|
      data
    end
    Thread.new do
      @client1.open read: @r1, write: @w2
    rescue StandardError
      # That's OK
    end
  end

  def teardown
    @client1.close
  end

  def test_correct_key
    @client2 = IORequest::Client.new(authorizer: IORequest::Authorizer.by_secret_key('secret_key'))
    @client2.open read: @r2, write: @w1
    sleep 1 until @client2.open?

    re = @client2.request({ a: 1 })
    assert_equal 1, re[:a]

    @client2.close
  end

  def test_incorrect_key
    @client2 = IORequest::Client.new(authorizer: IORequest::Authorizer.by_secret_key('aaa'))
    assert_raises RuntimeError do
      @client2.open read: @r2, write: @w1
    end
    @client2.close
  end
end
