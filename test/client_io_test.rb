# frozen_string_literal: true

require_relative 'test_helper'

class ClientIOTest < Minitest::Test
  def setup
    @r1, @w1 = IO.pipe
    @client1 = IORequest::Client.new
    @client1.open read: @r1, write: @w2

    @r2, @w2 = IO.pipe
    @client2 = IORequest::Client.new
    @client2.open read: @r2, write: @w1
  end

  def teardown
    @client1.close
    @client2.close
  end

  def test_simple_request
    @client2.respond do |_data|
      { num: 1, string: 'str' }
    end

    @client1.request do |data|
      assert_equal(1, data[:num])
      assert_equal('str', data[:string])
      assert_nil(data[:sync])
      assert_nil(data[:timeout])
    end
  end

  def test_intersecting_requests
    total = 10

    @client2.respond do |data|
      sleep data[:sleep_time]
      { num: data[:num] }
    end

    requests = Array.new(total) do |i|
      @client1.request({ sleep_time: total - i, num: i }) { |data| assert_equal(i, data[:num]) }
    end

    requests.each(&:join)
  end
end
