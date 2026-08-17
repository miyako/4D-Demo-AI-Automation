//%attributes = {}
#DECLARE($params : Object)

If (Count parameters=0)
	
	CALL WORKER(1; Current method name; {window: Frontmost window})
	
Else 
	
	var $weather : cs.WeatherService:=cs.WeatherService.me
	$weather.refreshUpcomingEvents($params.window)
	
	//var $today : Date:=Current date
	//var $cutoff : Date:=$today+15
	//var $events : cs.EventSelection:=ds.Event.query("status = :1 AND eventDate >= :2 AND eventDate <= :3"; "confirmed"; $today; $cutoff)
	//var $event : cs.EventEntity
	//$event:=$events.first()
	
	//$weather.fetchForEvent($event; $params.window)
	
End if 