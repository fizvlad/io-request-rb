# frozen_string_literal: true

require_relative 'test_helper'

class ClientIOTest < Minitest::Test
  def setup
    @r1, @w1 = IO.pipe
    @r2, @w2 = IO.pipe

    @client_1 = IORequest::Client.new read: @r1, write: @w2
    @client_2 = IORequest::Client.new read: @r2, write: @w1
  end

  def teardown
    @r1.close
    @w1.close
    @r2.close
    @w2.close
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
