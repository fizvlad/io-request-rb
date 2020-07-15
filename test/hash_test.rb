# frozen_string_literal: true

require_relative 'test_helper'

class HashTest < Minitest::Test
  def test_keys
    h = { 'a' => 1, :b => 2, 123 => 456 }
    h.symbolize_keys!
    assert_equal({ :a => 1, :b => 2, 123 => 456 }, h)
  end

  def test_keys_nested
    h = { 'a' => 1, :b => 2, 123 => { 'a' => 'b', 'b' => [123] } }
    h.symbolize_keys!
    assert_equal({ :a => 1, :b => 2, 123 => { a: 'b', b: [123] } }, h)
  end

  def test_keys_empty
    h = {}
    h.symbolize_keys!
    assert_equal({}, h)
  end

  def test_contains
    a = { a: 1, b: 2, c: 3 }
    b = { a: 1, b: 2 }

    assert(a.contains?(b))
    refute(b.contains?(a))
  end

  def test_contains_empty
    a = {}
    b = {}
    c = { a: 1 }

    assert(a.contains?(b))
    assert(b.contains?(a))

    assert(c.contains?(a))
    refute(a.contains?(c))
  end

  def test_contains_shared_object
    a = { a: 1 }
    b = { a: a }
    c = { a: a, b: b }

    assert(c.contains?(b))
    refute(b.contains?(c))
  end
end
