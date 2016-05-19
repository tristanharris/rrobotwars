require 'rrobots'

class Hunter
  include Robot

  # Project Hunter
  # 
  # One highly intelligent robot with an excellent tracking system
  # It should be evasive and snipe it's targets down.
  # We want to be able to predict the next place someone will be based on their previous movements and shoot there instead
  #
  #
  #
  #
  #
  attr :pending
  
  def init
    @timer = 0
    @found_enemy = false
    @pending = {}
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

  def get_enemy_location
    enemy_x = x + Math.cos((get_angle * Math::PI) / 180) * get_distance_to_enemy
    enemy_y = y - Math.sin((get_angle * Math::PI) / 180) * get_distance_to_enemy
    @enemy_pos = {enemy_x: enemy_x, enemy_y: enemy_y}
  end

  def calculate_angle
     ## first we need to figure out our angle to shoot, we can get this from our current x and y
     ## and compare those to our destination x and y i.e. our enemies
     @rad = Math.atan2((@enemy_pos[:enemy_y] - y),(@enemy_pos[:enemy_x] - x))
     angle = @rad * (180 / Math::PI)
     angle = 360 - angle if angle < 180 and angle > 0
     angle = 0 - angle if angle < 0
     @pending[:angle] = angle
     @found_enemy = false
  end

  def check_radar
    #turn_radar(10)
    turn_gun(10)
    # we found them!
    if found_enemy then
      # reset our timer
      @timer = 0
      @found_enemy = true
      # get a rough estimate of the enemys x and y pos
      get_enemy_location
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

  def basic_move
    accelerate(1)
    turn_tank(1)      
    turn_tank(-1) if found_enemy
    fire (3) if found_enemy
    fire(0.3)
  end

  def run_pending
    if @pending[:angle] then
      #puts "pending angle: #{@pending[:angle]} gun heading: #{gun_heading}"
      if @pending[:angle] > gun_heading then
        turn_gun(5)
        pending[:angle] = nil if within(gun_heading, @pending[:angle], 10)
      else
        turn_gun(-5)
      end
    end
  end

  def run_actions
    check_radar if @timer >= 50
    calculate_angle if @found_enemy == true
    run_pending
    basic_move
  end

  def tick events
    init if time == 0
    @timer+= 1

    run_actions
  end

end
