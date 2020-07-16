# frozen_string_literal: true

require_relative 'test_helper'

class MessageTest < Minitest::Test
  def test_id_uniqueness
    messages = []
    threads = []
    2.times do
      threads << Thread.new do
        1_000.times do |i|
          msg = IORequest::Message.new({ i: i })
          messages << msg
        end
      end
    end
    threads.each(&:join)

    message_ids = messages.map(&:id)
    message_ids.uniq!
    assert_equal messages.size, message_ids.size
  end

  def test_message_rw
    io_r, io_w = IO.pipe
    msg1 = IORequest::Message.new({ str: 'string', num: 42 })
    msg1.write_to(io_w)
    msg2 = IORequest::Message.read_from(io_r)
    assert_equal msg1.data, msg2.data
  end
end
