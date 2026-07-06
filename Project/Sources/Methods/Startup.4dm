//%attributes = {}
#DECLARE($params : Object)
// Startup.4dm
// Startup method for the Event Pulse application
// Called automatically by the Database Method "On Startup"
// AI provider and models configured in AIProviders.json

// Open the main hub data seeding is triggered manually via the Init button

var $title : Text:="ホーム"

If (Count parameters=0)
	
	ARRAY LONGINT($windows; 0)
	WINDOW LIST($windows)
	
	var $i; $window : Integer
	For ($i; 1; Size of array($windows))
		$window:=$windows{$i}
		If (Get window title($window)=$title) && (Window process($window)=1)
			CALL FORM($window; Formula(Form._activate.call()))  //FC_Home
			return 
		End if 
	End for 
	
	CALL WORKER(1; Current method name; {title: $title})
	
Else 
	
	var $w : Integer:=Open form window("Home"; Plain form window; Horizontally centered; Vertically centered)
	SET WINDOW TITLE($params.title; $window)
	DIALOG("Home"; *)  //FC_Home
	//CLOSE WINDOW($w)
	
End if 