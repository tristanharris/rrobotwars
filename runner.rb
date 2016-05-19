require 'rrobots'

class Numeric
	def deg
		self * Math::PI / 180
	end
	def rad
		self * 180 / Math::PI
	end
	def angle_add inval
		(self + inval) % 360
	end
	def angle_subtract inval
		(self - inval) % 360
	end
	def angle_anticlockwiseof inval
		# Can we reach inval by turning anticlockwise faster than we can reach it by turning clockwise (negative)
		((inval - self)%360) < 180
	end
end

# Changes to make
# 1- Gun actually sprays about a centre angle, rather than directly at it
# 2- When we loose lock (or don't acquire it) we sweep about the target point
# 3. Change the calc gun angle to take parameters
# 4. When we find a target follow it
# 5. Motion compensation for direction of our travel
# 6- Split the gun and target control out into a seperate module

# Two current problems
# 1. The radar doesn't attempt to track the motion compensated position
# 2. The system doesn't drop the use of estimated positions when the radar gets a rough lock elsewhere
# 3. We don't keep using our dx,dy every turn once calculated

class Runner
  include Robot

  def calc_enemy_pos
	# Using our current X position, current Y position and distance calculate the estimated position of the enemy
	# puts("Calculating pos using X of #{x}, Y of #{y} and distance of #{@enddistance} - angle #{@endangle}")
	# @startangle=@startangle-15;
	# TODO: As well as storing the start and end angle, also store the start and end X and Y positions
	# TODO: May re-introduce the enddistance variable again
	xa=(x+Math.cos(@startangle.deg) * @startdistance).to_i
	ya=(y-Math.sin(@startangle.deg) * @startdistance).to_i
	xb=(x+Math.cos(@endangle.deg) * @startdistance).to_i
	yb=(y-Math.sin(@endangle.deg) * @startdistance).to_i
	@enemyx=(xb-xa)/2 + xa
	@enemyy=(yb-ya)/2 + ya
	@enemydistance=@startdistance
	# puts("With angle calculated as #{@enemyx},#{@enemyy} distance #{@enemydistance}")
  end

  def calc_gun_angle(sweep_size,radarmode)
      at=time-@estimatereft
      if (at>5) 
	at=5
      end
      if radarmode==0
	if @estimatereft>0  
	  ax=@estimaterefx+(@enemydx*at*(@enemydistance/35))
	  ay=@estimaterefy+(@enemydy*at*(@enemydistance/35))
	  # puts("dx,dy = #{@enemydx},#{@enemydy} time = #{at} distance= #{@enemydistance/40}")
	  # puts("Using #{ax},#{ay} instead of #{@enemyx},#{@enemyy} for gun")
	else
	  # Using our sensed position
	  ax=@enemyx
	  ay=@enemyy
	end
      else
	# We dont want to calculate for bullet time of flight here, so just use referenec position + time*single step
	if radarmode==1 and @estimatereft>0
	  ax=@estimaterefx+(@enemydx*at)
	  ay=@estimaterefy+(@enemydy*at)
	  # puts("Using #{ax},#{ay} instead of #{@enemyx},#{@enemyy} for radar")
	else
	  # Using our sensed position
	  ax=@enemyx
	  ay=@enemyy
	end
      end
      if ax<0
	ax=0
      end
      if ax>battlefield_width
	ax=battlefield_width
      end
      if ay<0
	ay=0
      end
      if ay>battlefield_height
	ay=battlefield_height
      end
	dx=ax-x
	dy=y-ay
	if sweep_size > 0
	  sprayt=(time.to_i%(sweep_size*2))
	  if sprayt<sweep_size * 0.5
	    spray=0-sprayt
	  else
	    if sprayt < sweep_size * 1.0
	      spray=sweep_size-sprayt
	    else
	      if sprayt < sweep_size * 1.5
		spray=sprayt-sweep_size
	      else
		spray=sweep_size*2 - sprayt
	      end
	    end
	  end
	else
	  spray=0
	end
	# puts("Spray #{spray}")
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
  end

  def tick events
    if time == 0
	# Radar control variables
	@targetting=0
	@sweepsize=0
	@sweepdir=0
	@previousradarheading=0
      
	@startangle=0
	@endangle=0
	@startdistance=0
	@enddistance=0
	
	@radarturnrequired=0
	@gunturnrequired=0
	@tankturnrequired=0
	
	@enemydistance=0

	@direction = 0
	@locked = 0
	@enemyx=0
	@enemyy=0

	@enemydx=0
	@enemydy=0
	@estimaterefx=0
	@estimaterefy=0
	@estimatereft=0

	@targetangle=0
	@lostcount=0
	@mission_phase=0
	# debuggingenabled(1)

	@knownpositions=[]
	
    end
    # say("#{@direction} A #{@locked} S #{@startpos} E #{@endpos} D #{@enddistance} G #{gun_heading} R #{radar_heading} V #{velocity} ")
    if @targetting==5
      say("L")
    else
      # say("-")
      say(@targetting)
    end
    radar_control(events)
    target_control(events)
    case @mission_phase
    when 0
      lineup
    when 1
      mission_phase_one(events)
    when 2
      lineup
    when 3
      mission_phase_three(events)
    when 4
      mission_phase_four(events)
    end
    doactions
    # STDIN::gets
  end
  
  def target_control events
    # Deal with pointing the gun at the target and shooting
    if @targetting == 0
	if @direction==1 
		if gun_heading.to_i != 0
			@gunturnrequired=3
		end
	end
	if @direction==3 
		if gun_heading.to_i != 180
			@gunturnrequired=3
		end
	end
	if @direction > 4
	  # We set this direction when we not doing the up/down thing and we should simply sweep the gun
	  @gunturnrequired=3
	end
    else
	if @targetting > 0
	  if @targetting==5 
		# Try and point the gun in the exact direction requested
		calc_gun_angle(10,0)
	  else
	        # We don't have a precise lock, so spray around the target a bit more
		calc_gun_angle(15,0)
	  end
	  # puts("Target angle #{@targetangle} Cur Heading #{gun_heading}")
	  turn_amount=(gun_heading-@targetangle).abs
	  if turn_amount>2
		# puts("TA: #{turn_amount}")
		if (turn_amount>30)
			turn_amount=30
		end
		if gun_heading.angle_anticlockwiseof(@targetangle)
			@gunturnrequired=turn_amount
		else
			@gunturnrequired=0-turn_amount
		end
	  end
	end
    end
    fire 0.1
  end
  
  def sweepalter
    if @sweepdir==1
      # Means growing the sweep size
      if @sweepsize.to_i<30
	@sweepsize*=2
      else
	@targetting=0
      end
    else
      # Means shrinking the sweep size
      if @sweepsize.to_i<4
	@targetting=5
	store_known_position
      else
	@sweepsize/=2
      end
    end
  end
  
  def clear_estimates
	@estimaterefx=0
	@estimaterefy=0
	@estimatereft=0
	
	@enemydx=0
	@enemydy=0
  end
  
  def store_known_position
    posobj={}
    posobj[:x]=@enemyx
    posobj[:y]=@enemyy
    posobj[:t]=time
    
    @knownpositions << posobj
    
    # Only store 5 positions - probably no point storing more
    if @knownpositions.count>5
      @knownpositions.shift
    end
    
    # puts("Current known positions")
    # puts @knownpositions
    
    # Work out the dx and dy if we have at least 4 positions
    if @knownpositions.count>4
	deltapos=[]
	for i in 1..4
	  dposobj={}
	  dposobj[:x]=(@knownpositions[i][:x]-@knownpositions[i-1][:x]).to_f
	  dposobj[:y]=(@knownpositions[i][:y]-@knownpositions[i-1][:y]).to_f
	  dposobj[:t]=(@knownpositions[i][:t]-@knownpositions[i-1][:t]).to_f
	  dposobj[:h]=Math.sqrt((dposobj[:x]*dposobj[:x])+(dposobj[:y]*dposobj[:y]))/dposobj[:t]
	  if dposobj[:h]<8
	    deltapos << dposobj
	  end
	end
	if deltapos.count>2
	  #puts("Deltas")
	  #puts deltapos
	  # deltapos.sort! { |ax,ay| ax[:h] <=> ay[:h] }
	  # puts("Sorted deltas")
	  # puts deltapos
	  # Take the average of the first two (i.e. the two smallest deltas) - may change this to be the most common
	  # tdx = ((deltapos[0][:x]/deltapos[0][:t])+(deltapos[1][:x]/deltapos[1][:t]))/2
	  # tdy = ((deltapos[0][:y]/deltapos[0][:t])+(deltapos[1][:y]/deltapos[1][:t]))/2
	  tdx = ((deltapos[deltapos.count-1][:x]/deltapos[deltapos.count-1][:t])+(deltapos[deltapos.count-2][:x]/deltapos[deltapos.count-2][:t]))/2
	  tdy = ((deltapos[deltapos.count-1][:y]/deltapos[deltapos.count-1][:t])+(deltapos[deltapos.count-2][:y]/deltapos[deltapos.count-2][:t]))/2
	
	  @estimaterefx=@enemyx
	  @estimaterefy=@enemyy
	  @estimatereft=time
	
	  @enemydx=tdx
	  @enemydy=tdy
	
	  # puts("Found new dx,dy to be #{tdx},#{tdy}")
	end
    else
      clear_estimates
    end
    
    
  end
  
  def radar_control events
    # Control where the radar points and update the storaged enemy location if found
    # radar states
    # targetting 0 means we don't have a lock - scan as quickly as possible all around (positive dir)
    # targetting 1 means we've got initial contact and stored the start angle and are now waiting to loose contact to store the end angle (scanning positive dir)
    # targetting 2 means we're waiting for initial contact scanning backwards (negative dir)
    # targetting 3 means we've got backwards contact and are looking to loose contact to store the end angle
    # targetting 4 means we've lost contact going backwards and are now waiting for contact again going forwards with a smaller angle - this then jumps to state 2
    # targetting 5 means we've narrowed the angle as much as possible - keep radar on this heading with a small sweep (2) until loss - jump to state 2 incase of loss
    
    # sweepsize = the current radar sweep size
    # sweepdir = Are we growing or shrinking the sweep
    
    if events['robot_scanned'].empty?
      tfound=0
      tdist=0
    else
      tfound=1
      tdist=events['robot_scanned'][0][0].to_i
    end

    # puts("Pre:")
    # puts("T #{@targetting} Found #{tfound} Pre-H #{@previousradarheading} H #{radar_heading} Sweep size #{@sweepsize} Sweep dir #{@sweepdir} Start #{@startangle} End #{@endangle}")


    case @targetting
    when 0
      # targetting 0 means we don't have a lock - scan as quickly as possible all around (positive dir)
      if events['robot_scanned'].empty?
	# Turn quickly
	@radarturnrequired=30
	# @knownpositions=[]
	clear_estimates
      else
	# Store the start location and now sweep more slowly
	@sweepsize=28
	@sweepdir=0
	@startangle=@previousradarheading.to_i
	@startdistance=events['robot_scanned'][0][0].to_i
	# Might as well start firing - nothing to loose
	@endangle=radar_heading.to_i
	calc_enemy_pos()
	@radarturnrequired=@sweepsize
	@targetting=1
      end
    when 1
      # targetting 1 means we've got initial contact and stored the start angle and are now waiting to loose contact to store the end angle (scanning positive dir)
      if events['robot_scanned'].empty?
	# Lost contact
	@endangle=@previousradarheading.to_i
	calc_enemy_pos()
	@radarturnrequired=0-@sweepsize
	@targetting=2
	@sweepdir=0
        sweepalter
      else
	# Still got contact - keep scanning
	@radarturnrequired=@sweepsize
      end
    when 2
      # targetting 2 means we're waiting for initial contact scanning backwards (negative dir)
      if events['robot_scanned'].empty?
	# Not found anything - keep turning
	if @lostcount<4
	  @radarturnrequired=0-@sweepsize
	else
	  # Turn at this rate in the other direction
	  @targetting=4
	  @radarturnrequired=@sweepsize
	end
      else
	# Found something
	@endangle=@previousradarheading.to_i
	@startdistance=events['robot_scanned'][0][0].to_i
	calc_enemy_pos()
	# Keep turning backwards until we find it
	@radarturnrequired=0-@sweepsize
	@targetting=3
      end
    when 3
      # targetting 3 means we've got backwards contact and are looking to loose contact to store the end angle
      if events['robot_scanned'].empty?
	# Lost contact
	@startangle=@previousradarheading.to_i
	calc_enemy_pos()
	@radarturnrequired=@sweepsize
	@targetting=4
	@sweepdir=0
        sweepalter
      else
	# Still got contact - keep scanning
	@radarturnrequired=0-@sweepsize
      end
    when 4
      # targetting 4 means we've lost contact going backwards and are now waiting for contact again going forwards with a smaller angle - this then jumps to state 2
      if events['robot_scanned'].empty?
	# Not found anything - keep turning
	if @lostcount<13
	  @radarturnrequired=@sweepsize
	else
	  # We've lost it completly - go back to targetting of 0
	  @targetting=0
	end
      else
	# Found something
	@startangle=@previousradarheading.to_i
	@startdistance=events['robot_scanned'][0][0].to_i
	calc_enemy_pos()
	# Keep turning forwards until we loose it
	@radarturnrequired=@sweepsize
	@targetting=2
      end
    when 5
     if events['robot_scanned'].empty?
       # We've lost the target - start widening our scan about the estimated position
       if @lostcount<5
	if @estimatereft>0
	  calc_gun_angle(0,2)
	  minangle=@targetangle
	  calc_gun_angle(0,1)
	  maxangle=@targetangle
	  # puts("Min angle #{minangle} max angle #{maxangle} radar #{radar_heading}")
	  if maxangle.angle_anticlockwiseof(minangle)
	    # We estimate we need to keep moving in a positive direction
	    if maxangle.angle_anticlockwiseof(radar_heading)
	      # The radar is already past the estimated point - we want to scan backwards
	      @radarturnrequired=-5
	    else
	      # The radar is before the estimate point - scan forwards
	      @radarturnrequired=5
	    end
	  else
	    # We estimate we need to keep moving in a negative direction
	    if minangle.angle_anticlockwiseof(radar_heading)
	      # The radar is already past the estimated point - we want to scan forwards
	      @radarturnrequired=4
	    else
	      # The radar is before the estimate point - scan backwards
	      @radarturnrequired=-4
	    end
	  end
	else
	  # We don't have a valid estimated position - use the old widening spray aproach
	  calc_gun_angle(@lostcount*2,2)
          turn_amount=(radar_heading-@targetangle).abs
	  if (turn_amount>30)
	    turn_amount=30
	  end
	  if radar_heading.angle_anticlockwiseof(@targetangle)
	     @radarturnrequired=turn_amount
	  else
	     @radarturnrequired=0-turn_amount
	  end 
	end
 	# puts("Turn calc #{@radarturnrequired}")
       else
	@sweepdir=1
	@radarturnrequired=@sweepsize
	@targetting=4
       end
     else
       # We've still got sight of the target
	@startangle=@previousradarheading.to_i
	@endangle=radar_heading.to_i
	calc_enemy_pos()
	store_known_position
	calc_gun_angle(2,1)
	turn_amount=(radar_heading-@targetangle).abs
	if turn_amount>2
	  # puts("TA: #{turn_amount}")
	  if (turn_amount>30)
	    turn_amount=30
	  end
	  if radar_heading.angle_anticlockwiseof(@targetangle)
	     @radarturnrequired=turn_amount
	  else
	     @radarturnrequired=0-turn_amount
	  end
	end
     end
    end
    if events['robot_scanned'].empty?
	@lostcount=@lostcount+1
    else
	@lostcount=0
    end
    # Store for use in the calculations next time
    @previousradarheading=radar_heading

    # puts("Post:")
    # puts("T #{@targetting} Found #{tfound} Pre-H #{@previousradarheading} H #{radar_heading} RC #{@radarturnrequired} Sweep size #{@sweepsize} Sweep dir #{@sweepdir} Start #{@startangle} End #{@endangle}")
    # puts(" ")
    
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
	  @tankturnrequired=10
	else
	  @locked=1
	end
      end
      if x > battlefield_width/2
	# We need to drive left (angle 180)
	if heading.to_i !=180
	  @tankturnrequired=10
	else
	  ~@locked=1
	end
      end
    end
    if @locked==1
      if velocity != 7
	accelerate(1)
      end
    end
    if @locked==2
      stop
    end
  end
  
  def lineup
    if heading.to_i % 10 != 0
	@tankturnrequired=1
    else
	@locked=0
	@mission_phase=@mission_phase+1
    end
  end

  def mission_phase_three events
    # Change direction if necessary
    if @direction == 0
        if heading.to_i != 90
		@tankturnrequired=10
	end
    end
    if @direction == 2
	if heading.to_i != 270 
		@tankturnrequired=10
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
  end
  
  def mission_phase_four events
    # Follow a target if we have mission_phase_one
    if @targetting == 0
      @mission_phase = 0
      return
    end
    # Drive towards enemyx and enemyy
    distancetoenemy = Math::hypot(@enemyx-x,@enemyy-y)
    if distancetoenemy > 300 and velocity < 8
      accelerate(1)
    end
    if distancetoenemy < 301
      stop
    end
    calc_gun_angle(0)
    used_heading = heading
    if (@targetangle - heading).abs > 180
	    used_heading=heading+360;
    end
    # puts("Target angle #{@targetangle} Cur Heading #{used_heading}")
    if (used_heading-@targetangle).abs>2
	turn_amount=(used_heading-@targetangle).abs
	# puts("TA: #{turn_amount}")
	if (turn_amount>10)
		turn_amount=10
	end
	if heading<@targetangle
		@tankturnrequired=turn_amount
	else
		@tankturnrequired=0-turn_amount
	end
    end    
  end
end

def doactions
  # puts("Tank turn #{@tankturnrequired} Gun turn #{@gunturnrequired} Radar turn #{@radarturnrequired}")
  gt = @gunturnrequired-@tankturnrequired
  rt = @radarturnrequired-(@gunturnrequired+@tankturnrequired)
  turn(@tankturnrequired)
  turn_gun(gt)
  turn_radar(rt) 
  @tankturnrequired=0
  @gunturnrequired=0
  @radarturnrequired=0
end
