class Angle

  include Comparable

  attr_reader :deg

  def initialize(deg, offset=0)
    @deg = (deg + offset) % 360
  end

  def method_missing(name, *args)
    if deg.respond_to?(name)
      args.map! do |a|
        a = a.deg if a.respond_to?(:deg)
        a
      end
      res = deg.send(name, *args)
      return Angle.new(res) if res.is_a?(Numeric)
      return res
    else
      super
    end
  end

  def coerce(other)
    [Angle.new(other), self]
  end

  def ==(other)
    if %i[north south east west].include?(other)
      angle = Angle.new({north: 0, south: 180, east: 90, west: 270}[other])
      return ((angle - 90)..(angle + 89)).include?(self)
    end
    super
  end

  def <=>(other)
    if other.respond_to? :deg
      test = deg <=> other.deg
    else
      test = deg <=> other
    end
    -test.abs
  end

  def succ
    self + 1
  end

  def to_s
    deg.to_s
  end

  def to_i
    deg
  end

  def quickest_to(other)
    struct = Struct.new(:angle, :direction)
    return struct.new(0, 0) if self == other
    a = (self - other).to_i
    angle = [a, (other - self).to_i].min
    return struct.new(angle, a == angle ? -1 : 1)
  end

end
