require 'rrobots'

class Hunter
  include Robot

  # Project Hunter
  # 
  # One highly intelligent robot with an excellent tracking system
  # It should be evasive and snipe it's targets down.
  # We want to be able to predict the next place someone will be based on their previous movements and shoot there instead
  #
  # Phase 1: Move round the outside of the screen 
  #

  attr :pending
  
  def init
    @timer = 0
    @found_enemy = false
    @pending = {}
    @pending[:turn_gun] = true
    @halt = false;

    @enemy_x = 0
    @enemy_y = 0
    
    @top_left = {x: size, y: size}
    @top_right = {x: battlefield_width - size, y: size}
    @bottom_right = {x: battlefield_width - size, y: battlefield_height - size}
    @bottom_left = {x: size, y: battlefield_height - size}

    @top_left_bool = false
    @top_right_bool = false
    @bottom_right_bool = false
    @bottom_left_bool = false
    @phase1_complete = false

    @turn_speed = 10
    @gun_speed = 10

    @enemy_positions = []
    @enemy_lock = false
  end

  def got_hit
    if !events['got_hit'].empty? then
      return true
    else
      return false
    end
  end

  def found_enemy
    if !events['robot_scanned'].empty? then
      return true
    else
      return false
    end
  end

  def get_angle
    return radar_heading
  end

  def get_distance_to_enemy
    return events['robot_scanned'][0][0]
  end

  def calculate_enemy_pos heading, distance
    enemy_x = x + Math.cos((heading * Math::PI) / 180) * distance
    enemy_y = y - Math.sin((heading * Math::PI) / 180) * distance
    return {x: enemy_x, y: enemy_y}
  end

  def calculate_angle pos
     ## takes a pos hash in the form { x: x, y: y}
     ## first we need to figure out our angle to shoot, we can get this from our current x and y
     ## and compare those to our destination x and y i.e. our enemies
     rad = Math.atan2((pos[:y] - y),(pos[:x] - x)) # confusingly, this takes the x and y in reverse
     angle = rad * (180 / Math::PI)
     angle = 360 - angle if angle < 180 and angle > 0
     angle = 0 - angle if angle < 0
     return angle.to_i
  end

  def get_enemy_location
    # estimate the x and y position of our enemy
    enemy_pos = get_enemy_xy
    @enemy_x = enemy_pos[:x]
    @enemy_y = enemy_pos[:y]
    # with that info we can calculate the angle we need to shoot at and send our penging gun angle to that 
    pending[:turn_gun] = calculate_angle(enemy_pos)
    # set found enemy to be false, we don't want to continue calculating these
    @found_enemy = false
  end

  def check_radar
    
    if found_enemy then
      @enemy_pos = calculate_enemy_pos(radar_heading, get_distance_to_enemy)
      @enemy_x = @enemy_pos[:x]
      @enemy_y = @enemy_pos[:y]
      @enemy_lock = true
    end
    turn_radar(10)
    #say "#{@enemy_x},#{@enemy_y}"
  end

  def within a, b, threshold
    temp = a.abs - b.abs
    if temp.abs <= threshold then
      return true
    else
      return false
    end
  end

  def turn_tank amount
    turn(amount)
  end

  # phase 1 
  # move round the outside edges
  def phase_1

    if @phase1_complete == true then
      init
      pending[:dest] = @top_left
    end

    if speed > 0 and @gun_lock == true then 
      if time.to_i.even? then
        turn_gun(2)
      else 
        turn_gun(-2)
      end
    end
    
    pending[:dest] = @top_left if time == 0
    pending[:dest] = @top_right if @top_left_bool == true
    pending[:dest] = @bottom_right if @top_right_bool == true
    pending[:dest] = @bottom_left if @bottom_right_bool == true

    @top_left_bool = true if close_enough(@top_left[:x], @top_left[:y], size)
    @top_right_bool = true if close_enough(@top_right[:x], @top_right[:y], size)
    @bottom_right_bool = true if close_enough(@bottom_right[:x], @bottom_right[:y], size)
    @bottom_left_bool = true if close_enough(@bottom_left[:x], @bottom_left[:y], size)

    @phase1_complete = true if @bottom_left_bool == true

  end

  def close_enough dest_x, dest_y, proximity
    if (dest_x - x).abs < proximity and (dest_y - y).abs < proximity then
      return true
    end
  end

  def run_pending
    if @pending[:turn_gun] then
      @angle = calculate_angle({x: @enemy_x, y: @enemy_y} )
      direction = ((gun_heading - @angle) % 360 - (@angle - heading) % 360) <=> 0
      step = [@gun_speed, (gun_heading - @angle).abs].min
      turn_gun(direction * step)
    end
    # we've been told to move somewhere...
    if @pending[:dest] then
      @dest_angle = calculate_angle(@pending[:dest]).to_i
      # hold on to your hats
      # OK. first of all we need to check if we are facing the x and y coord's or not
      if heading != @dest_angle then
        @turn_speed = 1 if (heading - @dest_angle).abs < 15
        if heading < @dest_angle then
          turn(@turn_speed)
        else
          turn(-@turn_speed)
        end
      end
      if heading == @dest_angle then
        accelerate(1)
        if close_enough(pending[:dest][:x], pending[:dest][:y], size) then
          @pending[:dest] = nil
          @halt = true
          @turn_speed = 10
        end
      end
     
    end
  end

  def run_actions
    check_radar
    fire(0.3)
    stop if @halt == true;
    @halt = false if speed == 0
    run_pending
    
    phase_1
  end

  def tick events
    init if time == 0
    @timer+= 1
    run_actions
  end

end
