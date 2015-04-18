# ==================================================================================
# Class Mark
#     part from Actor
#
# Sample of Actor namely Märk Hammerfist the Warrior Blacksmith of Westerland.
# Mark harnesses basic movements and actions akin to Simon Belmont, in addition
# he also can do walljump.
# ==================================================================================

class Mark < Actor
	attr_reader 	:direction, :invincible, :last_x 
	attr_accessor	:y_flag, :sword, :status, :action, :running, :animations
	trait :bounding_box, :scale => [0.3, 0.8], :debug => false
	traits :timer, :collision_detection, :velocity
	
	def setup
		self.input = {
			:holding_left => :move_left,
			:holding_right => :move_right,
			:holding_down => :crouch,
			:holding_up => :steady,
			[:released_left, :released_right, :released_down, :released_up] => :stand,
			:z => :jump,
			:x => :fire,
			:c => :change_subweapon
		}
		@animations = Chingu::Animation.new( :file => "player/mark.gif", :size => [32,32])
		@animations.frame_names = {
			:stand => 0..2,
			:step => 3..3,
			:walk => 4..11,
			:jump => 12..14,
			:hurt => 15..17,
			:die => 17..17,
			:crouch => 18..19,
			:stead => 20..20,
			:shoot => 20..23, # 21..23,
			:crouch_shoot => 24..27,
			:raise => 28..30,
			:wall_jump => 31..31
		}
		@animations[:stand].delay = 50
		@animations[:stand].bounce = true
		@animations[:walk].delay = 60 # 65
		@image = @animations[:stand].first
		@speed = 2
		@status = :stand
		@action = :stand
		@invincible = false
		@jumping = false
		@vert_jump = false
		@running = false
		@subattack = false
		@sub = [:knife, :axe, :torch, :rang]
		self.zorder = 250
		@acceleration_y = Honoka::Environment::GRAV_ACC
		self.max_velocity = Honoka::Environment::GRAV_CAP
		self.rotation_center = :bottom_center
		
		# Idle animation? Idle animation.
		every(120){
			unless die?
				if @action == :stand && @status == :stand && @last_x == @x
					during(9){
						@image = @animations[:stand].next
					}.then{@image = @animations[:stand].reset; @image = @animations[:stand].first}
				end
			end
		}
		
		# Yet other flags
		@last_x, @last_y = @x, @y
		@y_flag = @y

		# Trait feature that creates a bounding box for collision detection and stuffs.
		# Without this, Mark can't stand on very ground.
		cache_bounding_box
	end
	

	# Reset player's flags. Useful when respawning Mark on Scene.
	def reset_state
		@status = :stand; @action = :stand
		@sword = nil
		@invincible = false
		@jumping = false
		@vert_jump = false
		@running = false
		@subattack = false
	end
	
	def at_edge?
		@x < (bb.width/2)  || @x > parent.area[0]-(bb.width/2) unless @status == :blink
	end
	
	def die?
		return false if $window.hp > 0
		return true if $window.hp <= 0
	end
	
	def disabled
		@status == :hurt or @status == :die
	end
	
	def blinking
		@status== :blink
	end
	
	def standing
		@status == :stand
	end
	
	def idle
		@action == :stand
	end
	
	def jumping
		@status == :jump
	end
	
	def falling
		@status == :fall
	end
	
	def crouching
		@status == :crouch
	end
	
	def steading
		@status == :stead
	end
	
	def attacking
		@action == :attack
	end
	
	def attacking_on_ground
		@action == :attack && @status == :stand && @velocity_y < Honoka::Environment::GRAV_WHEN_LAND + 1
	end
	
	def damaged
		@status == :hurt
	end
	
	def knocked_back
		@status == :hurt and moved?
	end
	
	def raising_sword
		@action == :raise
	end
	
	def moving_to_another_area
		$window.transfer
	end
	
	def on_wall
		@status == :walljump
	end
	
	def walljumping
		@action == :walljump
	end
	
	def holding_subweapon?
		$window.subweapon != :none
	end
	
	def in_event
		$window.in_event
	end
	
	def stand
		unless jumping or disabled or die? or @y != @y_flag or not idle
			@image = @animations[:stand].first
			@status = :stand
			@running = false
			@jumping = false
		end
	end
	
	def crouch
		unless jumping or disabled or attacking or die? or disabled
			@image = @animations[:crouch].first
			@status = :crouch
		end
	end
	
	def steady
		unless jumping or disabled or attacking or die? or disabled
			@image = @animations[:stead].first
			@status = :stead
		end
	end
	
	def land
		delay = 18
		delay = 24 if attacking
		if (@y - @y_flag > 56 or (@y - @y_flag > 48 && jumping ) ) && !die?
			Sound["sfx/step.wav"].play
			between(1,delay) { 
				@status = :crouch; crouch
			}.then { 
				if !die?; @status = :stand; @image = @animations[:stand].first; end
			}
		else
			if jumping or on_wall or falling
				@image = @animations[:stand].first unless Sword.size >= 1
				@status = :stand 
			elsif @velocity_y >= Honoka::Environment::GRAV_WHEN_LAND + 1 # 2
				@image = @animations[:stand].first unless Sword.size >= 1
				@velocity_y = Honoka::Environment::GRAV_WHEN_LAND # 1
			end
		end
		@jumping = false if @jumping
		@vert_jump = false if !@jumping
		@velocity_x = 0
		@y_flag = @y
	end
	
	def move_left
		return if attacking_on_ground or walljumping or raising_sword
		return if crouching or steading
		return if moving_to_another_area or in_event
		return if die? or disabled
		move(-@speed, 0)
	end
	
	def move_right
		return if attacking_on_ground or walljumping or raising_sword
		return if crouching or steading
		return if moving_to_another_area or in_event
		return if die? or disabled
		move(@speed, 0)
	end
	
	def jump
		return if on_wall and @jumping
		if on_wall and not attacking and not @jumping and holding_any?(:left, :right)
			@action = :walljump
			@sword.die if @sword != nil
			@y_flag = @y
			self.factor_x *= -self.factor_x.abs
			@velocity_y = 0
			#~ between(1,100){ 
			between(1,6){ 
				@image = @animations[:wall_jump].first
				@velocity_y = 0
			}.then{
				@x += 4 * self.factor_x
				@image = @animations[:jump].first
				@status = :jump; @jumping = true
				#~ @action = :stand
				Sound["sfx/jump.wav"].play
				@velocity_x = 4 * self.factor_x
			}
			between(6,15){
				@velocity_y = -6 if @jumping
				@velocity_y = -2 if !@jumping
			}
			after(15){ @action = :stand; @velocity_y = -2 if @jumping; @y_flag = @y; @velocity_x = 0}
		else
			return if self.velocity_y > Honoka::Environment::GRAV_WHEN_LAND # 1
			return if crouching or jumping or damaged or die? or not idle or on_wall
			@status = :jump
			@jumping = true
			Sound["sfx/jump.wav"].play
			@velocity_y = -4
			during(9){
				@vert_jump = true if !holding_any?(:left, :right)
				if holding?(:z) && @jumping && !disabled
					@velocity_y = -4  unless @velocity_y <=  -Honoka::Environment::GRAV_CAP || !@jumping
				else
					@velocity_y = -1 unless !@jumping
				end
			}
		end
	end
	
	def raise
		@action = :raise
		dir = [self.velocity_x, self.velocity_y]
		@image = @animations[:shoot].last
		@sword.die if @sword != nil
		factor = (self.factor_x^0)*(-1)
		self.velocity_x = self.velocity_y = @acceleration_y = 0
		@image = @animations[:raise].first
		@sword = Sword.create(:x => @x+(5*factor), :y => (@y-15), :factor_x => -factor, :angle => 90*factor)
		after(500) {@sword.die; @image = @animations[:stand].first; @image = @animations[:jump].last if @status == :jump; @action = :stand; self.velocity_x, self.velocity_y = dir[0], dir[1]; @acceleration_y = 0.3}
	end
	
	def weapon_up
		raise
	end
	
	def limit_subweapon
		Knife.size >= Honoka::ALLOWED_SUBWEAPON_THROWN || 
		Axe.size >= Honoka::ALLOWED_SUBWEAPON_THROWN || 
		Torch.size >= Honoka::ALLOWED_SUBWEAPON_THROWN || 
		Rang.size >= Honoka::ALLOWED_SUBWEAPON_THROWN
	end
	
	def land?
		self.each_collision(*$window.terrains) do |me, stone_wall|
			if me.y >= stone_wall.bb.bottom and self.velocity_y < 0 # Hitting the ceiling
				me.y = stone_wall.bb.bottom + me.image.height * me.factor_y
				me.velocity_y = 0
				@jumping = false
			elsif walljumping
				@jumping = false
				me.x = stone_wall.bb.right + (me.image.width/4) if me.x > stone_wall.x
				me.x = stone_wall.bb.left - (me.image.width/4) if me.x < stone_wall.x
			else  # Land on ground
				if damaged
					hurt
				else
					land
				end
				me.velocity_y = Honoka::Environment::GRAV_WHEN_LAND # 1
				me.y = stone_wall.bb.top - 1 # unless me.y > stone_wall.y
			end
		end
		self.each_collision(*$window.bridges) do |me, bridge|
			if me.y <= bridge.y+2 && me.velocity_y > 0
				if damaged
					hurt
				else
					land
				end
				me.velocity_y = Honoka::Environment::GRAV_WHEN_LAND # 1
				me.y = bridge.bb.top - 1
			end
		end
	end

	def knockback(damage)
		return if @invincible
		@invincible = true
		@status = :hurt
		@action = :stand
		@sword.destroy if @sword != nil
		Sound["sfx/grunt.ogg"].play(0.8)
		$window.hp -= damage # 3
		$window.hp = 0 if $window.hp <= 0
		self.velocity_x = (self.factor_x*-1)
		self.velocity_y = -4
		land?
	end
	
	def hurt
		@velocity_x = 0
		@jumping = false
		if not die?
			#~ between(1,500) { 
			between(1,30) { 
				@status = :crouch; crouch
			}.then { @status = :stand; @image = @animations[:stand].first}
			between(30,120){@color.alpha = 128}.then{@invincible = false; @color.alpha = 255}
		else
			dead
		end
	end

	def dead
		$window.hp = 0
		@sword.die if @sword != nil
		@status = :die
		@image = @animations[:stand].last
		after(6){@image = @animations[16]}
		after(12){
			@image = @animations[:die].first
			@x += 8*@factor_x unless @y > ($window.height/2) + parent.viewport.y
			#~ game_state.after(1500) { 
			game_state.after(90) { 
				@sword.die if @sword != nil
				reset_state
				$window.reset_stage
				parent.clear_game_terrains
			}
		}
	end
	
	def move(x,y)
		return if blinking
		if x != 0 and not (jumping or on_wall)
			@image = @animations[:step].first if !@running
			@image = @animations[:walk].next if @running
			#~ after(50) { @running = true if not @running }
			after(2) { @running = true if not @running }
		end
		
		@image = @animations[:hurt].first  if damaged
		@image = @animations[:raise].first  if raising_sword
		
		unless attacking or damaged or on_wall
			self.factor_x = self.factor_x.abs   if x > 0
			self.factor_x = -self.factor_x.abs  if x < 0
		end
		
		unless raising_sword or (on_wall and @jumping)
			@x += x if !@vert_jump and not falling
			@x += x/2 if @vert_jump or falling
		end

		self.each_collision(*$window.terrains) do |me, stone_wall|
			@x = previous_x
			#~ if @jumping and (@y_flag - @y).abs > 8
			if @jumping # (@y_flag - @y).abs > 8
				if stone_wall.x < me.x and holding?(:left); @status = :walljump; @jumping = false; end
				if stone_wall.x > me.x and holding?(:right); @status = :walljump; @jumping = false; end
			end
			break
		end
		
		if @x != previous_x and on_wall and !@jumping
			@status = :jump; @jumping = true
		end
		
		@x = previous_x  if at_edge? and not in_event

		@y += y
	end
	
	def check_last_direction
		if @x == @last_x && @y == @last_y or @subattack
			@direction = [self.factor_x*(2), 0]
		else
			@direction = [@x - @last_x, @y - @last_y]
		end
		@last_x, @last_y = @x, @y
	end
	
	def fire
		unless disabled or raising_sword or walljumping or die?
			if holding?(:up) and holding_subweapon?
				unless attacking || crouching || limit_subweapon
					attack_sword if $window.ammo == 0
					attack_subweapon if $window.ammo != 0
				end
			else
				unless Sword.size >= 1
					attack_sword
				end
			end
		end
	end
	
	def change_subweapon
		@sub = @sub.rotate
		$window.subweapon = @sub[0]
	end
	
	def attack_sword
		@action = :attack
		@image = @animations[:shoot].first if not crouching
		@image = @animations[:crouch_shoot].first if crouching
		factor = -(self.factor_x^0)
		@sword = Sword.create(:x => @x+(5*factor), :y => (@y-14), :velocity => @direction, :factor_x => -factor, :angle => 90*(-factor_x))
		between(1, 6) {
			unless disabled or raising_sword
				@sword.x = @x+(9*(-factor_x))
				@sword.y = (@y-(self.height/2)-1) if standing
				@sword.y = (@y-(self.height/2)+4) if crouching or jumping
				@sword.angle = 120*(-factor_x)
				@sword.velocity = @direction
			end
		}. then {
			Sound["sfx/swing.wav"].play
			unless disabled or raising_sword
				@image = @animations[:crouch_shoot][1] if crouching
				@image = @animations[:shoot][1] if not crouching
			end
		}
		between(6,10) {
			unless disabled or raising_sword
				@sword.x = @x+(9*(-factor_x))
				@sword.y = (@y-(self.height/2)+1)
				@sword.y = (@y-(self.height/2)+6) if crouching
				@sword.angle = 140*(-factor_x)
				@sword.velocity = [0,0]
			end
		}.then {
			unless disabled or raising_sword
				@image = @animations[:crouch_shoot][2] if crouching
				@image = @animations[:shoot][2] if not crouching
			end
			@sword.bb.height = (@sword.bb.width)*-1 + 8
			@sword.angle = 130*(-factor_x) unless raising_sword
			@sword.collidable = true
		}
		between(10,15) {
			unless disabled or raising_sword
				@sword.x += (6*factor_x)
				@sword.y = (@y-(self.height/2)-4)
				@sword.y = (@y-(self.height/2)+1) if crouching
				@sword.angle -= 30*(-factor_x)
				@sword.velocity = [0,0]
			end
		}.then {
			unless disabled or raising_sword
				@image = @animations[:crouch_shoot][3] if crouching
				@image = @animations[:shoot][3] if not crouching
			end
			@sword.bb.height = ((@sword.bb.width*1/10))
		}
		#~ between(175, 350) {
		between(15,32) {
			unless disabled or raising_sword
				@sword.zorder = self.zorder - 1
				@sword.x = @x-(13*factor)+((-1)*factor)
				@sword.x = @x-(11*factor)+((-1)*factor) if crouching
				@sword.y = (@y-(self.height/2)+6)
				@sword.y = (@y-(self.height/2)+11) if crouching
				@sword.angle = 0*(-factor_x/2)
				@image = @animations[:crouch_shoot].last if crouching
			end
		}.then {
			unless disabled or raising_sword
				@sword.die
				@action = :stand
				unless disabled
					@image = @animations[:stand].first if standing or steading
					@image = @animations[:crouch].first if crouching
					@image = @animations[:jump].last if jumping
				end
				@status = :stand if steading || !holding?(:down)
			end
			@animations[:shoot].reset
			@animations[:crouch_shoot].reset
		}
	end
	
	def attack_subweapon
		@action = :attack
		@subattack = true
		@image = @animations[:shoot][0]
		between(6,12) { 
			@image = @animations[:shoot][1]
		}.then{
			@image = @animations[:shoot][2]
			$window.ammo -= 1
			case $window.subweapon
				when :knife
					Knife.create(:x => @x+(10*factor_x), :y => @y-(self.height/2), :velocity => @direction, :factor_x => factor_x) unless Knife.size >= Honoka::ALLOWED_SUBWEAPON_THROWN
				when :axe
					Axe.create(:x => @x+(8*factor_x), :y => @y-(self.height/2)-4, :velocity => @direction, :factor_x => factor_x) unless Axe.size >= Honoka::ALLOWED_SUBWEAPON_THROWN
				when :torch
					Torch.create(:x => @x+(12*factor_x), :y => @y-(self.height/2), :velocity => @direction, :factor_x => factor_x) unless Torch.size >= Honoka::ALLOWED_SUBWEAPON_THROWN
				when :rang
					Rang.create(:x => @x+(12*factor_x), :y => @y-(self.height/2), :velocity => @direction, :factor_x => factor_x) unless Rang.size >= Honoka::ALLOWED_SUBWEAPON_THROWN
			end
			Sound["sfx/swing.wav"].play
		}
		#~ after(200) { @image = @animations[:shoot].last}
		between(12,32) { 
		#~ after(350) {  
			@image = @animations[:shoot].last
			@image = @animations[:crouch_shoot].last if crouching
		}.then {
			@action = :stand
			@status = :stand if steading
			unless disabled
				@image = @animations[:stand].first if standing or steading
				@image = @animations[:crouch].first if crouching
				@image = @animations[:jump].last if jumping
			end
			@animations[:shoot].reset
			@animations[:crouch_shoot].reset
		}
	end
	
	def update
		land?
		@velocity_y = Honoka::Environment::GRAV_CAP if @velocity_y > Honoka::Environment::GRAV_CAP
		if @x == @last_x
			@running = false
			@animations[:walk].reset
		end
		if (jumping or on_wall) and idle
			if @last_y > @y 
				@image = @animations[:jump].first
				@image = @animations[13] if @vert_jump
			else
				@image = @animations[13] if @velocity_y <= 2
				@image = @animations[:jump].last if @velocity_y > 2
			end
		end
		check_last_direction
		if @velocity_y > Honoka::Environment::GRAV_WHEN_LAND + 1 && !jumping && idle && !on_wall
			@status = :fall unless disabled
			@image = @animations[13] if @velocity_y <= 3
			@image = @animations[:jump].last if @velocity_y > 3
		end
		self.each_collision(Rang) do |me, weapon|
			weapon.die
		end
		@y_flag = @y if @velocity_y == Honoka::Environment::GRAV_WHEN_LAND && !@jumping
	end
end