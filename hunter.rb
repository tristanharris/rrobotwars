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
    @halt = false;

    @top_left = { x: 512, y: 512 }
    @top_left_set = false
    @bottom_left = { x: size, y: battlefield_height - size}
    @bottom_left_set = false
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

  def get_enemy_xy
    enemy_x = x + Math.cos((get_angle * Math::PI) / 180) * get_distance_to_enemy
    enemy_y = y - Math.sin((get_angle * Math::PI) / 180) * get_distance_to_enemy
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
    # with that info we can calculate the angle we need to shoot at and send our penging gun angle to that 
    pending[:gun_angle] = calculate_angle(enemy_pos)
    # set found enemy to be false, we don't want to continue calculating these
    @found_enemy = false
  end

  def check_radar
    # just turn our gun, if we do find something our gun will be pointing at it already.
    turn_gun(10)
    # set our gun lock to false.. we dont really want to be spraying all the time
    @gun_lock = false;

    if found_enemy then
      # reset our timer
      @timer = 0
      # set our found enemy bool to be true 
      # we check this is true in our run_actions function
      @found_enemy = true
    end
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
    @pending[:dest] = @top_left if @top_left_set == false
    @top_left_set = true
  end

  def run_pending
    if @pending[:gun_angle] then
      if @pending[:gun_angle] > gun_heading then
        turn_gun(5)
        pending[:gun_angle] = nil if within(gun_heading, @pending[:gun_angle], 10)
        @gun_lock = true if pending[:angle].nil?
      else
        turn_gun(-5)
      end
    end
    # we've been told to move somewhere...
    if @pending[:dest] then
      @dest_angle = calculate_angle(@pending[:dest]).to_i
      # hold on to your hats
      # OK. first of all we need to check if we are facing the x and y coord's or not
      if heading != @dest_angle then
        if heading > @dest_angle then
         turn(-1)
        else 
          turn(1)
        end
      end
      if heading == @dest_angle then
        puts (pending[:dest][:x] - x).abs
        puts (pending[:dest][:y] - y).abs
        if (pending[:dest][:x] - x).abs < 30 && (pending[:dest][:y] - y).abs < 30 then
          puts "at our destination"
          @pending[:dest] = nil
          @halt = true
        end
      end
      accelerate(1)
    end
    if @pending[:dest] then

    end
  end

  def run_actions
    check_radar if @timer >= 25
    get_enemy_location if @found_enemy == true
    fire(0.3) if @gun_lock == true
    stop if @halt == true;
    @halt = false if speed == 0
    run_pending
    if time < 2000 then
      phase_1
    end
  end

  def tick events
    init if time == 0
    @timer+= 1

    run_actions
  end

end
