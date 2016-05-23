require 'rrobots'

class Deadpool
  include Robot
srand
  def tick events
	fire 0.1 unless events['robot_scanned'].empty?
    spin=(rand(1..2)*2)-3
    tickrand = rand(10)
	if time == 0 then
	   @dirn=1
	   bobble = 0
	   @xx = 0
	   @yy = 0
	   @elapsed = 0
	   @there = 90
	   @twist = spin
	   turn_radar 1
	end
	accelerate @dirn

	if x=@xx or y=@yy then
	   @elapsed += 40
	   @twist = spin
	end
	
	if @elapsed > 0 then
	   turn 10*@twist
	   turn_gun -10*@twist+5
	   @elapsed -= 1
	else
	   turn tickrand*@twist
	   turn_gun -tickrand*@twist+5
	end
	
	@dirn= -1*@dirn unless events['got_hit'].empty?
	if events['got_hit'].empty? then
	else
		say('Is that all you can do!') unless events['got_hit'].empty?
		say('I am invincible') if energy < 10 and bobble != 5
	end
	bobble = 5 if energy < 5
	#Aim
	turn_radar 60 if events['robot_scanned'].empty?
	#puts 'radar ', radar_heading, 'scan', events['robot_scanned']
		
	@there = radar_heading unless events['robot_scanned'].empty?
	
	
	#  if @there-gun_heading > 180
	#turn_gun @there unless @there == 0


	@xx = x
	@yy = y
	
	
  end
end
