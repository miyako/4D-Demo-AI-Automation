// FC_EventList.4dm
// Liste des événements avec indicateurs météo et filtres

property events : Collection
property activeFilter : Text
property running : Boolean
property currentEvent : Object
property showPast : Boolean

Class constructor()
	This.events:=[]
	This.activeFilter:="all"
	This.running:=False
	This.currentEvent:=Null
	This.showPast:=False

//MARK: - Form & form objects event handlers
Function formEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Load)
			This._onLoad()
		: ($formEventCode=On Double Clicked)
			This._onDoubleClicked()
	End case 

Function btnRefreshEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._refreshWeather()
	End case 

Function btnFilterAllEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("all")
	End case 

Function btnFilterConfirmedEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("confirmed")
	End case 

Function btnFilterQuoteEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("quote")
	End case 

Function btnFilterWeatherEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("weather")
	End case 

Function btnFilterEmailEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("email")
	End case 

Function btnTogglePastEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This.showPast:=Not(This.showPast)
			If (This.showPast)
				OBJECT SET TITLE(*; "btn_toggle_past"; "✓ Past Events")
			Else 
				OBJECT SET TITLE(*; "btn_toggle_past"; "Show Past")
			End if 
			This._loadEvents(This.activeFilter)
	End case 

//MARK: - Private
Function _onLoad()
	This._loadEvents("all")

Function _onDoubleClicked()
	If (This.currentEvent#Null)
		var $evt : cs.EventEntity:=ds.Event.get(This.currentEvent.id)
		If ($evt#Null)
			var $ids : Collection:=This.events.extract("id")
			var $fc : cs.FC_EventDetail:=cs.FC_EventDetail.new($evt; $ids)
			var $w : Integer:=Open form window("EventDetail"; Plain form window)
			DIALOG("EventDetail"; $fc)
			CLOSE WINDOW($w)
			This._loadEvents(This.activeFilter)
		End if 
	End if 

Function _setFilter($filter : Text)
	This.activeFilter:=$filter
	This._loadEvents($filter)

Function _loadEvents($filter : Text)
	var $selection : cs.EventSelection
	var $today : Date:=Current date

	Case of 
		: ($filter="confirmed")
			If (This.showPast)
				$selection:=ds.Event.query("status = :1"; "confirmed").orderBy("eventDate ASC")
			Else 
				$selection:=ds.Event.query("status = :1 AND eventDate >= :2"; "confirmed"; $today).orderBy("eventDate ASC")
			End if 
		: ($filter="quote")
			If (This.showPast)
				$selection:=ds.Event.query("status = :1"; "quote").orderBy("eventDate ASC")
			Else 
				$selection:=ds.Event.query("status = :1 AND eventDate >= :2"; "quote"; $today).orderBy("eventDate ASC")
			End if 
		: ($filter="weather")
			If (This.showPast)
				$selection:=ds.Event.query("weatherAlertLevel != :1"; "none").orderBy("eventDate ASC")
			Else 
				$selection:=ds.Event.query("weatherAlertLevel != :1 AND eventDate >= :2"; "none"; $today).orderBy("eventDate ASC")
			End if 
		: ($filter="email")
			If (This.showPast)
				$selection:=ds.Event.query("emails.emailStatus = :1"; "unread").orderBy("eventDate ASC")
			Else 
				$selection:=ds.Event.query("emails.emailStatus = :1 AND eventDate >= :2"; "unread"; $today).orderBy("eventDate ASC")
			End if 
		Else 
			If (This.showPast)
				$selection:=ds.Event.all().orderBy("eventDate ASC")
			Else 
				$selection:=ds.Event.query("eventDate >= :1"; $today).orderBy("eventDate ASC")
			End if 
	End case 

	var $result : Collection:=[]
	var $evt : cs.EventEntity
	var $venue : cs.VenueEntity
	var $client : cs.ClientEntity
	var $item : Object

	// Pre-compute which event IDs have unread emails (for icon column — avoids N+1 queries)
	var $unreadEmailIDs : Collection:=ds.Email.query("emailStatus = :1 AND linkedEventID != :2"; "unread"; "").toCollection("linkedEventID").extract("linkedEventID")

	For each ($evt; $selection)
		$venue:=$evt.venue
		$client:=$evt.client
		$item:={id: $evt.ID}
		$item.eventDateStr:=String($evt.eventDate; "dd/MM/yyyy")
		$item.clientName:=Choose($client#Null; $client.companyName; "—")
		$item.venueName:=Choose($venue#Null; $venue.name; "—")
		$item.venueCity:=Choose($venue#Null; $venue.city; "—")
		$item.guestCountStr:=String($evt.guestCount)
		$item.contractRef:=$evt.contractRef
		$item.status:=$evt.status
		$item.weatherAlertLevel:=$evt.weatherAlertLevel
		$item.statusBadge:=This._statusBadge($evt.status)
		$item.weatherIcon:=This._weatherIcon($evt.weatherAlertLevel)
		$item.emailIcon:=Choose($unreadEmailIDs.indexOf(String($evt.ID))>=0; "📧"; "")
		$item.venueOption:=Choose($evt.venueOption="indoor"; "🏢"; "🌳")
		$item.plannedWeather:=This._weatherLabel($evt.weatherSetup)
		$item.forecastWeather:=This._weatherLabel($evt.weatherForecast)
		$result.push($item)
	End for each 

	// Single assignment triggers listbox binding refresh (critical for CALL FORM context)
	This.events:=$result

	OBJECT SET TITLE(*; "text_event_count"; String(This.events.length)+" events")

	// Update filter button counts
	This._updateFilterCounts()

Function _updateFilterCounts()
	var $today : Date:=Current date
	var $allCount : Integer
	var $confirmedCount : Integer
	var $quoteCount : Integer
	var $weatherCount : Integer
	var $emailCount : Integer

	If (This.showPast)
		$allCount:=ds.Event.all().length
		$confirmedCount:=ds.Event.query("status = :1"; "confirmed").length
		$quoteCount:=ds.Event.query("status = :1"; "quote").length
		$weatherCount:=ds.Event.query("weatherAlertLevel != :1"; "none").length
		$emailCount:=ds.Event.query("emails.emailStatus = :1"; "unread").length
	Else 
		$allCount:=ds.Event.query("eventDate >= :1"; $today).length
		$confirmedCount:=ds.Event.query("status = :1 AND eventDate >= :2"; "confirmed"; $today).length
		$quoteCount:=ds.Event.query("status = :1 AND eventDate >= :2"; "quote"; $today).length
		$weatherCount:=ds.Event.query("weatherAlertLevel != :1 AND eventDate >= :2"; "none"; $today).length
		$emailCount:=ds.Event.query("emails.emailStatus = :1 AND eventDate >= :2"; "unread"; $today).length
	End if 

	OBJECT SET TITLE(*; "btn_filter_all"; "All ("+String($allCount)+")")
	OBJECT SET TITLE(*; "btn_filter_confirmed"; "Confirmed ("+String($confirmedCount)+")")
	OBJECT SET TITLE(*; "btn_filter_quote"; "Quotes ("+String($quoteCount)+")")
	OBJECT SET TITLE(*; "btn_filter_weather"; "⚠ Weather ("+String($weatherCount)+")")
	OBJECT SET TITLE(*; "btn_filter_email"; "✉ Emails ("+String($emailCount)+")")

Function _refreshWeather()
	This.running:=True
	OBJECT SET TITLE(*; "btn_refresh"; "⏳ Updating...")

	var $window : Integer:=Current form window
	CALL WORKER("weatherWorker"; Formula(_weatherWorkerJob($window)))

Function _onWeatherDone()
	This.running:=False
	OBJECT SET TITLE(*; "btn_refresh"; "🌤 Refresh Weather")
	This._loadEvents(This.activeFilter)

Function _statusBadge($status : Text) : Text
	Case of 
		: ($status="confirmed")
			return "Confirmed"
		: ($status="quote")
			return "Quote"
		: ($status="completed")
			return "Done"
		: ($status="cancelled")
			return "Cancelled"
		Else 
			return $status
	End case 

Function _weatherIcon($level : Text) : Text
	Case of 
		: ($level="warning")
			return "⛈"
		: ($level="watch")
			return "🌧"
		: ($level="critical")
			return "🚨"
		Else 
			return ""
	End case 

Function _weatherLabel($setup : Object) : Text
	If ($setup=Null)
		return "—"
	End if 
	var $icon : Text
	Case of 
		: ($setup.conditions="indifferent")
			return "🏢 Indoor"
		: ($setup.conditions="rain")
			$icon:="🌧"
		: ($setup.conditions="sunny")
			$icon:="☀"
		Else 
			$icon:="❓"
	End case 
	var $temp : Text
	Case of 
		: ($setup.temperature="hot")
			$temp:="🔥"
		: ($setup.temperature="cold")
			$temp:="❄"
		Else 
			$temp:=""
	End case 
	return $icon+$temp
