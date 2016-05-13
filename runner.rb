require 'rrobots'

class Numeric
	def deg
		self * Math::PI / 180
	end
	def rad
		self * 180 / Math::PI
	end
end

# Changes to make
# 1. Gun actually sprays about a centre angle, rather than directly at it
# 2. When we loose lock (or don't acquire it) we sweep about the target point
# 3. Change the calc gun angle to take parameters

class Runner
  include Robot

  def calc_enemy_pos
	# Using our current X position, startpos, endpos and distance calculate the estimated position of the enemy
	# puts("Calculating pos using X of #{x}, Y of #{y} and distance of #{@enddistance} - angle #{@endangle}")
	# @startangle=@startangle-15;
	xa=(x+Math.cos(@startangle.deg) * @startdistance).to_i
	ya=(@startpos-Math.sin(@startangle.deg) * @startdistance).to_i
	xb=(x+Math.cos(@endangle.deg) * @enddistance).to_i
	yb=(@endpos-Math.sin(@endangle.deg) * @enddistance).to_i
	@enemyx=(xb-xa)/2 + xa
	@enemyy=(yb-ya)/2 + ya
	# puts("With angle calculated as #{@enemyx},#{@enemyy}")
  end

  def calc_gun_angle
	# Using our position x and y and the enemyx and enemyy positions calculate the angle the gun needs to be pointing
        dx=@enemyx-x
	dy=y-@enemyy
	spray=(time.to_i%4)-2
	if dy==0 
		dy=dy+1
	end
	@targetangle=Math.atan(dy/dx).rad + spray
	if @targetangle<0 
		@targetangle=@targetangle+360
	end
	if dx<0 
		@targetangle=@targetangle+180
	end
	if @targetangle>360 
		@targetangle=@targetangle-360
	end
	# @targetangle=270
	# puts("DX #{dx} DY #{dy} Target Angle #{@targetangle}")
  end

  def tick events
    if time == 0
	@direction = 0
	@locked = 0
	@startpos=0
	@endpos=0
	@startdistance=0
	@enddistance=0
	@enemyx=0
	@enemyy=0
	@startangle=0
	@endangle=0
	@targetting=0
	@targetangle=0
	@targetdir=0
	@lostcount=0
	@mission_phase=0
    end
    # say("#{@direction} A #{@locked} S #{@startpos} E #{@endpos} D #{@enddistance} G #{gun_heading} R #{radar_heading} V #{velocity} ")
    case @mission_phase
    when 0
      lineup
    when 1
      mission_phase_one(events)
    when 2
      lineup
    when 3
      mission_phase_three(events)
    end
  end
  
  def mission_phase_one events
    # Drive to middle of screen
    # check if we are in the middle
    if (x>(battlefield_width/2)-10 and x<(battlefield_width/2)+10) or @locked==2
      if velocity==0
	@locked=0
	@mission_phase=@mission_phase+1
      else
	@locked=2
      end
    end
    if @locked==0
      if x < battlefield_width/2
	# We need to drive right (angle zero)
	if heading.to_i != 0
	  turn(10)
	else
	  @locked=1
	end
      end
      if x > battlefield_width/2
	# We need to drive left (angle 180)
	if heading.to_i !=180
	  turn(10)
	else
	  ~@locked=1
	end
      end
    end
    if @locked==1
      if velocity != 4
	accelerate(1)
      end
    end
    if @locked==2
      stop
    end
  end
  
  def lineup
    if heading.to_i % 10 != 0
	turn(1)
    else
	@locked=0
	@mission_phase=@mission_phase+1
    end
  end

  def mission_phase_three events
    # Change direction if necessary
    if @direction == 0
        if heading.to_i != 90
		turn(10)
	end
    end
    if @direction == 2
	if heading.to_i != 270 
		turn(10)
	end
    end
    # We should always be either driving or turning
    if @direction == 0 and heading.to_i == 90 
	if velocity < 8
		accelerate(1)
	else
		@direction = 1
	end
    end
    if @direction == 1 and y < battlefield_height/10
	if velocity > 0
		# Decelerate
		accelerate(-1)
	else
		# Turn around
		@direction = 2
	end
    end
    if @direction == 2 and heading.to_i == 270
	if velocity < 8
		accelerate(1)
	else
		@direction = 3
	end
    end
    if @direction == 3 and y > battlefield_height - (battlefield_height / 10)
	if velocity > 0
		# Decelerate
		accelerate(-1)
	else
		# Turn around
		@direction = 0
	end
    end
    if @targetting==0
    	if events['robot_scanned'].empty?
		if @locked>0
			@endpos=y
			@locked=0
			@endangle=radar_heading.to_i
			calc_enemy_pos()
			@targetting=1
			@lostcount=0
		end
    	else
		# puts("#{events['robot_scanned'][0].inspect}")
		if @locked==0
			@startpos=y
			@startangle=radar_heading.to_i
			@startdistance=events['robot_scanned'][0][0].to_i
		end
       		@locked=@locked+1
		@enddistance=events['robot_scanned'][0][0].to_i
    	end
    else
	# Targetting of 1 means we turning the gun to point where we think the enemy is
	# Targetting of 2 means we've turned and failed to find the enemy
	# Targetting of 3 means we've turned the gun and found the enemy again
	if events['robot_scanned'].empty?
		@lostcount=@lostcount+1
		if @lostcount>50
			@targetting=0
			@locked=0
		end
	else
		# Lock on
		@targetting = 3
		# Update position
		@startpos=y
		@endpos=y
		@startangle=radar_heading.to_i
		@endangle=radar_heading.to_i
		@startdistance=events['robot_scanned'][0][0].to_i
		@enddistance=@startdistance
		@lostcount=0
		calc_enemy_pos()
	end
    end
    # Deal with pointing the gun in a consistent direction
    if @targetting == 0
	if @direction==1 
		if gun_heading.to_i != 0
			turn_gun(3)
		else
			if radar_heading.to_i < 2
				turn_radar(2)
			else
				turn_radar(-2)
			end
		end
	end
	if @direction==3 
		if gun_heading.to_i != 180
			turn_gun(3)
		else
			if radar_heading.to_i < 2
				turn_radar(2)
			else
				turn_radar(-2)
			end
		end
	end
    else
	calc_gun_angle()
	if @targetting==1 or @targetting==3
		# Try and point the gun in the direction requested
		used_heading = gun_heading
		if (@targetangle - gun_heading).abs > 180
			used_heading=gun_heading+360;
		end
		# puts("Target angle #{@targetangle} Cur Heading #{used_heading}")
		if (used_heading-@targetangle).abs>2
			turn_amount=(used_heading-@targetangle).abs
			# puts("TA: #{turn_amount}")
			if (turn_amount>10)
				turn_amount=10
			end
			if gun_heading<@targetangle
				@targetdir=1
				turn_gun(turn_amount)
			else
				@targetdir=-1
				turn_gun(0-turn_amount)
			end
		else
			if @targetting==1 
				@targetting=2
			end
		end
	end
	if @targetting==2
		if @targetdir==1
			turn_gun(1)
		else
			turn_gun(-1)
		end
	end
    end
    if @locked!=2
      fire 1
    else
      fire 3
    end
    
    # unless events['robot_scanned'].empty?
  end
end
