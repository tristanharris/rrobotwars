require 'rrobots'

class Leeroyjenkins
  include Robot


  def tick events
    if time == 0

	@direction = 0
	@locked = 0
	@mission_phase=10
	@activebank=0
	@previousangle=0
	@banka=[]
	@bankb=[]
	@revcounter=0
    end
    dospeech
    case @mission_phase
    when 10
      lineup
    when 11
      findmidx(events)
    when 12
      findmidy(events)
    when 13
      spin(events)
    end
  end
  
  def dospeech
    if (energy>20)
      st=(time/100).to_i;
      
      case st
      when 1
	say("Alright chums, Let's do this!!!")
      when 3
	say("LEEEEEEEEEEEEEEEEROY JENKINS")
      when 5
	say("We've got em!")
      end
    else
      say("At least I have chicken")
    end
  end
  
  
  def findmidx events
    # Drive to middle x of screen
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
      if velocity != 7
	accelerate(1)
      end
    end
    if @locked==2
      stop
    end
  end
  
  def findmidy events
    # Drive to middle y of screen
    # check if we are in the middle
    if (y>(battlefield_height/2)-10 and y<(battlefield_height/2)+10) or @locked==2
      if velocity==0
	@locked=0
	@mission_phase=@mission_phase+1
      else
	@locked=2
      end
    end
    if @locked==0
      if y < battlefield_height/2
	# We need to drive right (angle zero)
	if heading.to_i != 270
	  turn(10)
	else
	  @locked=1
	end
      end
      if y > battlefield_height/2
	# We need to drive left (angle 180)
	if heading.to_i !=90
	  turn(10)
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
	turn(1)
    else
	@locked=0
	@mission_phase=@mission_phase+1
    end
  end

  def spin events
    firedthistick=0
    if (radar_heading%10)!=0
      turn(-1)
      fire 0.1
    else
      if radar_heading.to_i==0
	# At point zero - swap banks
	@revcounter+=1
	if @activebank==0
	  @activebank=1
	  @bankb=[]
	else
	  @activebank=0
	  @banka=[]
	end
      end
      if @revcounter<5
	fire 0.1
	turn(-10)
	return
      end
      if !(events['robot_scanned'].empty?)
	fire 1
	if @activebank==0
	  # Store in A
	  @banka << @previousangle-(@previousangle%10)
	else
	  # Store in B
	  @bankb << @previousangle-(@previousangle%10)
	end
      end
      # Check if need to fire
      if @activebank==0
	if @bankb.include?(radar_heading.to_i)
	  fire 0.1
	  firedthistick=1
	end
      else
	if @banka.include?(radar_heading.to_i)
	  fire 0.1
	  firedthistick=1
	end
      end
      if (firedthistick==1)
	turn(-1)
      else
	turn(-10)
      end
      @previousangle=radar_heading.to_i
    end
  end
end

