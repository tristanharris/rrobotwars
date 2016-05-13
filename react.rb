require 'rrobots'

class React
  include Robot

  def tick events
    if time == 0
      @run = 0
    end
    @run -= 1
    turn_gun 2
    turn 10 if @run % 50 == 0
    say velocity
    fire 3 unless events['robot_scanned'].empty?
    accelerate(-1) if velocity > 0 && @run < 0
    if !events['got_hit'].empty?
      accelerate 8
      turn 10
      @run = 300
    end
  end

end
