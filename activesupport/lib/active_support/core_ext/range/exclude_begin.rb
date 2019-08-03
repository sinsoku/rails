class Range
  def exclude_begin?
    false
  end

  def exclude_begin
    RangeExcludeBegin.new(self.begin, self.end, exclude_end?)
  end
end

class RangeExcludeBegin < Range
  def initialize(first, last, exclude_end = false)
    next_value = first.next
    @target = exclude_end ? next_value...last : next_value..last
    super
  end

  def exclude_begin?
    true
  end

  def each(&block)
    @target.each(&block)
  end

  def step(n = 1, &block)
    @target.step(n, &block)
  end
end
