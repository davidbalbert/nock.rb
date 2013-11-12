module Nock
  def self.[](*a)
    Cell.build(a)
  end

  class NockError < StandardError; end

  def self.Atom(value)
    Atom.new(value)
  end

  class Atom
    def initialize(value)
      unless value.is_a?(Integer) && value >= 0
        raise NockError, "#{value.inspect} is not a natural number"
      end

      @value = value
    end

    def to_s
      @value.to_s
    end

    def inspect
      "Nock::Atom(#{to_s})"
    end

    def ==(other)
      if other.is_a?(Atom)
        value == other.to_i
      else
        value == other
      end
    end

    def -(other)
      Atom.new(value - other)
    end

    def /(other)
      Atom.new(value / other)
    end

    def even?
      value.even?
    end

    def odd?
      value.odd?
    end

    def cell?
      Atom.new(1)
    end

    def inc
      Atom.new(value + 1)
    end

    def nock_equals?
      raise NockError, "=#{value} would loop forever"
    end

    def slot
      raise NockError, "/#{value} would loop forever"
    end

    def nock
      raise NockError, "*#{value} would loop forever"
    end

    def to_i
      @value
    end
    alias value to_i
  end

  class Cell
    def self.build(array)
      if array.size == 1
        raise NockError, "You can't have a Cell with only one item"
      end

      if array[0].is_a?(Array)
        first = build(array[0])
      else
        first = Atom.new(array[0])
      end

      if array.size == 2
        if array[1].is_a?(Array)
          rest = build(array[1])
        else
          rest = Atom.new(array[1])
        end

        new(first, rest)
      else
        new(first, build(array[1..-1]))
      end
    end

    attr_reader :first, :rest

    def initialize(first, rest)
      unless first.is_a?(Cell) || first.is_a?(Atom)
        raise NockError, "#{first} must be a Cell or an Atom"
      end

      unless rest.is_a?(Cell) || rest.is_a?(Atom)
        raise NockError, "#{rest} must be a Cell or an Atom"
      end

      @first = first
      @rest  = rest
    end

    def to_a
      ary = []
      cell = self

      while cell.is_a? Cell
        ary << cell.first
        cell = cell.rest
      end

      ary << cell

      ary
    end

    def to_s(show_nesting = false)
      if show_nesting

      else
        "[#{to_a.join(" ")}]"
      end
    end

    def inspect
      "Nock::Cell#{to_s}"
    end

    def ==(other)
      if other.is_a? Cell
        first == other.first && rest == other.rest
      else
        false
      end
    end

    def nock
      a = first
      op = rest.first
      b = rest.rest

      if op.is_a?(Cell)
        b = op.first
        c = op.rest
        d = rest.rest

        Cell.new(Cell.new(a, Cell.new(b, c)).nock, Cell.new(a, d).nock)
      elsif op == 0
        Cell.new(b, a).slot
      elsif op == 1
        b
      elsif op == 2
        b = rest.rest.first
        c = rest.rest.rest

        Cell.new(Cell.new(a, b).nock, Cell.new(a, c).nock).nock
      elsif op == 3
        Cell.new(a, b).nock.cell?
      elsif op == 4
        Cell.new(a, b).nock.inc
      elsif op == 5
        Cell.new(a, b).nock.nock_equals?
      elsif op == 6
        b = rest.rest.first
        c = rest.rest.rest.first
        d = rest.rest.rest.rest

        # *[a 2 [0 1] 2 [1 c d] [1 0] 2 [1 2 3] [1 0] 4 4 b]
        # Cell.new(a ).nock
        raise "TODO"
      else
        raise NockError, "*#{to_s} doesn't make sense"
      end
    end

    def cell?
      Atom.new(0)
    end

    def inc
      raise NockError, "+#{self} would loop forever"
    end

    def slot
      n = first
      tree = rest

      if n == 0
        raise NockError, "/#{self} doesn't make sense"
      elsif n == 1
        tree
      elsif n == 2
        tree.first
      elsif n == 3
        tree.rest
      elsif n.even?
        Cell.new(Atom.new(2), Cell.new(n / 2, tree).slot).slot
      elsif n.odd?
        Cell.new(Atom.new(3), Cell.new((n - 1) / 2, tree).slot).slot
      end
    end

    def nock_equals?
      if first == rest
        Atom.new(0)
      else
        Atom.new(1)
      end
    end
  end
end

if $0 == __FILE__
  require 'minitest/autorun'

  include Nock

  def a(v)
    Atom.new(v)
  end

  class NockTest < MiniTest::Unit::TestCase
    def test_cell?
      assert_equal a(0), Nock[1, 2].cell?
      assert_equal a(1), a(42).cell?
    end

    def test_inc
      assert_equal a(43), a(42).inc
      assert_raises(NockError) { Nock[1, 2].inc }
    end

    def test_nock_equals?
      assert_equal a(0), Nock[10, 10].nock_equals?
      assert_equal a(1), Nock[10, 11].nock_equals?
      assert_raises(NockError) { a(5).nock_equals? }
    end

    def test_slot
      assert_equal a(5), Nock[1, 5].slot
      assert_equal a(5), Nock[2, 5, 10].slot
      assert_equal a(10), Nock[3, 5, 10].slot

      # complex cases
      list = Nock[[4, 5], [6, 14, 15]]

      assert_equal list, Cell.new(a(1), list).slot
      assert_equal Nock[4, 5], Cell.new(a(2), list).slot
      assert_equal Nock[6, 14, 15], Cell.new(a(3), list).slot
      assert_equal Nock[14, 15], Cell.new(a(7), list).slot

      assert_raises(NockError) { Nock[0, 1].slot }
      assert_raises(NockError) { a(5).slot }
    end

    def test_nock_0
      assert_equal Nock[2, 1, 2].slot, Nock[[1, 2], 0, 2].nock
    end

    def test_nock_1
      assert_equal a(50), Nock[42, 1, 50].nock
    end

    def test_nock_2
      assert_equal Nock[153, 218], Nock[77, [2, [1, 42], [1, 1, 153, 218]]].nock
    end

    def test_nock_3
      assert_equal a(0), Nock[123, 3, 1, 1, 2].nock
      assert_equal a(1), Nock[123, 3, 1, 1].nock
    end

    def test_nock_4
      assert_equal a(58), Nock[57, 4, 0, 1].nock
    end

    def test_nock_5
      assert_equal a(0), Nock[123, 5, 1, [12, 13], 12, 13].nock
      assert_equal a(1), Nock[123, 5, 1, [120, 130], 12, 13].nock
    end

    def test_nock_cell
      assert_equal Nock[43, 1], Nock[42, [[4, 0, 1], [3, 0, 1]]].nock
    end
  end
end
