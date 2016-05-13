require 'rrobots'

class React
  include Robot

  attr :pending

  def initialize
    @pending = {}
    turn_to(90, 2)
  end

  def tick events
    #turn_gun 2
    #fire 3 unless events['robot_scanned'].empty?
    #accelerate(-1) if velocity > 0 && @run < 0
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
  end

  def turn_to(angle, step)
    @pending[:turn] = {angle: angle, step: step}
  end

  def finish(action)
    @pending[action] = nil
  end

end
