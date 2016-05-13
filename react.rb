require 'rrobots'

class React
  include Robot

  attr :pending

  def initialize
    @pending = {}
    turn_to(90, 2)
    accelerate_to 8
  end

  def tick events
    #turn_gun 2
    #fire 3 unless events['robot_scanned'].empty?
    #if !events['got_hit'].empty?
    #  accelerate 8
    #  turn 10
    #  @run = 300
    #end
    run_actions
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
