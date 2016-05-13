require 'rrobots'

class React
  include Robot

  attr :pending

  def init
    @pending = {}
    turn_radar 2
    turn_to(90, 2)
    accelerate_to 8
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
    if velocity != 0
      case true
        when x <= size
          turn_to(heading + 90, 10)
        when x >= battlefield_width - size
          turn_to(heading - 90, 10)
        when y <= size
          turn_to(heading + 90, 10)
        when y >= battlefield_width - size
          turn_to(heading - 90, 10)
      end
    end
  end

  def run_actions
    if pending[:turn]
      angle = pending[:turn][:angle]
      if heading == angle
        finish :turn
      else
        step = pending[:turn][:step]
        dir = ((heading - angle) % 360 - (angle - heading) % 360) <=> 0
        step = [step, (heading - angle).abs].min
        turn dir * step
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
