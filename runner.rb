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

  def calc_gun_angle sweep_size
	if @estimatedpositionx>0 and @estimatedpositiony>0
	  dx=@estimatedpositionx-x
	  dy=y-@estimatedpositiony
	  puts("Using #{@estimatedpositionx},#{@estimatedpositiony} instead of #{@enemyx},#{@enemyy}")
	else
	  # Using our position x and y and the enemyx and enemyy positions calculate the angle the gun needs to be pointing
	  dx=@enemyx-x
	  dy=y-@enemyy
	end
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
	@estimatedpositionx=0
	@estimatedpositiony=0
	@enemyy=0
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
      say("-")
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
	  # if @targetting==5 
		# Try and point the gun in the exact direction requested
		calc_gun_angle(2)
	  # else
	        # We don't have a precise lock, so spray around the target
		# calc_gun_angle(5+@lostcount/4)
	  # end
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
    fire 0.3
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
    
    #puts("Current known positions")
    #puts @knownpositions
    
    # Work out the dx and dy if we have at least 4 positions
    if @knownpositions.count>4
	deltapos=[]
	for i in 1..4
	  dposobj={}
	  dposobj[:x]=@knownpositions[i][:x]-@knownpositions[i-1][:x]
	  dposobj[:y]=@knownpositions[i][:y]-@knownpositions[i-1][:y]
	  dposobj[:t]=@knownpositions[i][:t]-@knownpositions[i-1][:t]
	  dposobj[:h]=Math.sqrt((dposobj[:x]*dposobj[:x])+(dposobj[:y]*dposobj[:y]))/dposobj[:t]
	  deltapos << dposobj
	end
	#puts("Deltas")
	#puts deltapos
	#puts("Sorted deltas")
	deltapos.sort! { |ax,ay| ax[:h] <=> ay[:h] }
	#puts deltapos
	# Take the average of the first two (i.e. the two smallest deltas) - may change this to be the most common
	tdx = ((deltapos[0][:x]/deltapos[0][:t])+(deltapos[1][:x]/deltapos[1][:t]))/2
	tdy = ((deltapos[0][:y]/deltapos[0][:t])+(deltapos[1][:y]/deltapos[1][:t]))/2
	# Need to use distance here - 10 ticks for bullets to travel 400, to 40 pixels per tick travel
	@estimatedpositionx=@enemyx+(tdx*@enemydistance/40)
	@estimatedpositiony=@enemyy+(tdy*@enemydistance/40)
    else
      	@estimatedpositionx=0
	@estimatedpositiony=0
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
	@knownpositions=[]
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
	if @lostcount<8
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
       # We've lose the target - start widening our scan
	@sweepdir=1
	@radarturnrequired=@sweepsize
	@targetting=4
     else
       # We've still got sight of the target
	@startangle=@previousradarheading.to_i
	@endangle=radar_heading.to_i
	calc_enemy_pos()
	calc_gun_angle(2)
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
