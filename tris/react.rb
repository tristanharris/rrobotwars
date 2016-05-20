require 'rrobots'

require_relative 'lib/angle'

class React
  include Robot

  attr :pending

  def init
    @pending = {}
    turn_radar 2
    turn_to(20, 2)
    accelerate_to 8
  end

  def heading
    Angle.new(-super, 90)
  end

  def turn(value)
    super(-value)
  end

  def tick events
    init if time == 0
    turn_gun 2
    fire 3 unless events['robot_scanned'].empty?
    if !events['got_hit'].empty?
      accelerate_to 8
      turn_to rand(360), 10
    end
    run_actions
    check_walls
  end

  def check_walls
    walls = []
    walls << :north if y <= size
    walls << :south if y >= battlefield_height - size
    walls << :east  if x >= battlefield_width - size
    walls << :west  if x <= size
    if velocity != 0 && pending[:turn].nil? && !walls.empty?
      bounce = 0
      if (walls[0] == :west && heading == :south) ||
        (walls[0] == :east && heading == :north) ||
        (walls[0] == :north && heading == :west) ||
        (walls[0] == :south && heading == :east)
          bounce = -1
      end
      if (walls[0] == :west && heading == :north) ||
        (walls[0] == :east && heading == :south) ||
        (walls[0] == :north && heading == :east) ||
        (walls[0] == :south && heading == :west)
          bounce = 1
      end
      turn_to(heading + 90 * bounce, 10) unless bounce == 0
    end
  end

  def run_actions
    if pending[:turn]
      angle = pending[:turn][:angle]
      if heading == angle
        finish :turn
      else
        step = pending[:turn][:step]
        quick = heading.quickest_to(angle)
        step = [step, quick.angle].min
        turn quick.direction * step
      end
    end
    if pending[:accelerate]
      speed = pending[:accelerate][:speed]
      if velocity == speed
        finish(:accelerate)
      else
        dir = (speed - velocity) <=> 0
        accelerate dir
      end
    end
  end

  def turn_to(angle, step)
    @pending[:turn] = {angle: angle, step: step}
  end

  def accelerate_to(speed)
    @pending[:accelerate] = {speed: speed}
  end

  def finish(action)
    @pending[action] = nil
  end

end
