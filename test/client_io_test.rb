# frozen_string_literal: true

require_relative 'test_helper'

class ClientIOTest < Minitest::Test
  def setup
    @r1, @w1 = IO.pipe
    @r2, @w2 = IO.pipe

    @client1 = IORequest::Client.new
    @client2 = IORequest::Client.new

    @thread1 = Thread.new { @client1.open read: @r1, write: @w2 }
    @thread2 = Thread.new { @client2.open read: @r2, write: @w1 }
    sleep 1 until @client1.open? && @client2.open?
  end

  def teardown
    @client1.close
    @client2.close

    @thread1.join
    @thread2.join
  end

  def test_simple_request
    @client2.on_request do |_data|
      { num: 1, string: 'str' }
    end

    data = @client1.request
    assert_equal(1, data[:num])
    assert_equal('str', data[:string])
  end

  def test_intersecting_requests
    total = 10

    @client2.on_request do |data|
      sleep data[:sleep_time]
      { num: data[:num] }
    end

    Array.new(total) do |i|
      @client1.request({ sleep_time: total - i, num: i }) { |data| assert_equal(i, data[:num]) }
    end

    sleep total + 1
  end

  def test_on_close
    on_close_fired = false
    @client2.on_close do
      on_close_fired = true
    end
    @client2.close
    assert on_close_fired
  end

  def test_request_timeout
    @client2.on_request do |data|
      sleep data[:sleep_time]
      {}
    end

    assert_raises(IORequest::RequestTimeoutError) do
      @client1.request({ sleep_time: 6 }, timeout: 3)
    end
  end
end
