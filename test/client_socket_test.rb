require_relative "test_helper"

require "socket"

$PORT = 8000

class ClientSocketTest < Minitest::Test
  def setup
    $PORT += 1
    puts "Starting test at port #{$PORT}"
    @s = TCPServer.new($PORT)
    @c = TCPSocket.new("localhost", $PORT)
    @sc = @s.accept

    @client_1 = IORequest::Client.new read: @c, write: @c
    @client_2 = IORequest::Client.new read: @sc, write: @sc
  end
  def teardown
    @sc.close
    @c.close
  end

  def test_simple_request
    @client_2.respond do |request|
      { num: 1, string: "str" }
    end

    @client_1.request sync: true do |response|
      assert_equal(1, response.data[:num])
      assert_equal("str", response.data[:string])
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
