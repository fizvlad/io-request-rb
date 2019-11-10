require_relative "test_helper"

class TestingClass
  include IORequest::Utility::MultiThread

  attr_reader :num

  def initialize(num = 0)
    @num = num
    @mutex = Mutex.new
  end

  def inc_in(time, inc = 1)
    in_thread(inc) do |in_inc|
      sleep time
      @mutex.synchronize { @num += in_inc }
    end
  end

  def threads
    running_threads
  end

  def kill
    kill_threads
  end

  def join
    join_threads
  end

end

class MultiThreadTest < Minitest::Test

  WAIT_TIME = 2

  def test_in_thread 
    t = TestingClass.new(0)
    t.inc_in(WAIT_TIME, 1)
    sleep 1
    assert_equal(0, t.num)
    sleep WAIT_TIME
    assert_equal(1, t.num)
    assert_empty(t.threads)
  end

  def test_two_threads
    t = TestingClass.new(0)
    t.inc_in(WAIT_TIME, 1)
    t.inc_in(WAIT_TIME * 2, 2)
    sleep 1
    assert_equal(0, t.num)
    sleep WAIT_TIME
    assert_equal(1, t.num)
    sleep WAIT_TIME
    assert_equal(3, t.num)
    assert_empty(t.threads)
  end

  def test_killing_threads
    t = TestingClass.new(0)
    n = 10
    n.times { t.inc_in(WAIT_TIME, 1) }
    sleep 1
    t.kill
    assert_equal(0, t.num)
    assert_empty(t.threads)
  end

  def test_joining_threads
    t = TestingClass.new(0)
    n = 100
    n.times { t.inc_in(WAIT_TIME, 1) }
    sleep 1
    t.join
    assert_equal(n, t.num)
    assert_empty(t.threads)
  end

end
