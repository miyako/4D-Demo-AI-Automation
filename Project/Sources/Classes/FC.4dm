Class constructor()
	
Function _activate()
	
	var $x; $y; $r; $b; $window : Integer
	$window:=Current form window
	GET WINDOW RECT($x; $y; $r; $b; $window)
	SET WINDOW RECT($x; $y; $r; $b; $window)