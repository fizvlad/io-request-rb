require "test_helper"

class IORequestTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::IORequest::VERSION
  end
end
