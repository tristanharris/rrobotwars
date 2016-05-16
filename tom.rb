require 'rrobots'

class Tom
  include Robot
  @@turn_dir = 3

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

  def check_walls
  	# we hit the left wall
  	if x <= size then
  		@turn_check = true
  	# we hit the right wall
  	elsif x >= battlefield_width - size then
  		@turn_check = true
  	end
  	# we hit the top wall
  	if y <= size then
  		@turn_check = true
  	# we hit the bottom wall
  	elsif y >= battlefield_height - size then
  		@turn_check = true
  	end 
  end

  def basic_move
  	# check any collisions against walls first
  	check_walls
  	if @turn_check == true then
  		turn(90)
  	end

  	accelerate(1)
  end

  def tick events
  	basic_move
  	fire(0.2)
  	if found_enemy then
  		fire(3)
  		turn(@@turn_dir)
  	else 
  		turn(-(@@turn_dir))
  	end
  	
  	## did we get hit? reverse our turn direction!s
  	if got_hit then
  		@@turn_dir = -@@turn_dir
  	end

  end

end