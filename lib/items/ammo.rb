class Ammo < Items
	def setup; super; @color = Color.new(0xff00ff00); end
	def die; $window.ammo += 1; $window.ammo = 99 if $window.ammo > 99; super; end
end