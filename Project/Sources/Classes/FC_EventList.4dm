// FC_EventList.4dm
// Event list with weather indicators and filters

property events : cs.EventSelection
property activeFilter : Text
property running : Boolean
property currentEvent : cs.EventEntity
property showPast : Boolean
property _windowRef : Integer

Class extends FC

Class constructor()
	
	Super()
	This.events:=ds.Event.newSelection()
	This.activeFilter:="all"
	This.running:=False
	This.currentEvent:=Null
	This.showPast:=False
	This._windowRef:=0
	
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
	This._windowRef:=Current form window
	This._loadEvents("all")
	
Function _onDoubleClicked()
	If (This.currentEvent#Null)
		var $fc : cs.FC_EventDetail:=cs.FC_EventDetail.new(This.currentEvent; This.events; This)
		var $w : Integer:=Open form window("EventDetail"; Plain form window)
		DIALOG("EventDetail"; $fc; *)
		//CLOSE WINDOW($w)
		//This._loadEvents(This.activeFilter)
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
				$selection:=ds.Event.query("emails.emailStatus = :1"; "pending").orderBy("eventDate ASC")
			Else 
				$selection:=ds.Event.query("emails.emailStatus = :1 AND eventDate >= :2"; "pending"; $today).orderBy("eventDate ASC")
			End if 
		Else 
			If (This.showPast)
				$selection:=ds.Event.all().orderBy("eventDate ASC")
			Else 
				$selection:=ds.Event.query("eventDate >= :1"; $today).orderBy("eventDate ASC")
			End if 
	End case 
	
	var $l10n : Object:={}
	If (True)
		$l10n.events:=" イベント"
	Else 
		$l10n.events:=" events"
	End if 
	
	This.events:=$selection
	OBJECT SET TITLE(*; "text_event_count"; String(This.events.length)+$l10n.events)
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
		$emailCount:=ds.Event.query("emails.emailStatus = :1"; "pending").length
	Else 
		$allCount:=ds.Event.query("eventDate >= :1"; $today).length
		$confirmedCount:=ds.Event.query("status = :1 AND eventDate >= :2"; "confirmed"; $today).length
		$quoteCount:=ds.Event.query("status = :1 AND eventDate >= :2"; "quote"; $today).length
		$weatherCount:=ds.Event.query("weatherAlertLevel != :1 AND eventDate >= :2"; "none"; $today).length
		$emailCount:=ds.Event.query("emails.emailStatus = :1 AND eventDate >= :2"; "pending"; $today).length
	End if 
	
	//OBJECT SET TITLE(*; "btn_filter_all"; "All ("+String($allCount)+")")
	//OBJECT SET TITLE(*; "btn_filter_confirmed"; "Confirmed ("+String($confirmedCount)+")")
	//OBJECT SET TITLE(*; "btn_filter_quote"; "Quotes ("+String($quoteCount)+")")
	//OBJECT SET TITLE(*; "btn_filter_weather"; "⚠ Weather ("+String($weatherCount)+")")
	//OBJECT SET TITLE(*; "btn_filter_email"; "✉ Emails ("+String($emailCount)+")")
	OBJECT SET TITLE(*; "btn_filter_all"; "All ("+String($allCount)+")")
	OBJECT SET TITLE(*; "btn_filter_confirmed"; "確定 ("+String($confirmedCount)+")")
	OBJECT SET TITLE(*; "btn_filter_quote"; "商談中 ("+String($quoteCount)+")")
	OBJECT SET TITLE(*; "btn_filter_weather"; "⚠️ 天候アラート ("+String($weatherCount)+")")
	OBJECT SET TITLE(*; "btn_filter_email"; "📧 メール ("+String($emailCount)+")")
	
Function _refreshWeather()
	This.running:=True
	//OBJECT SET TITLE(*; "btn_refresh"; "⏳ Updating...")
	OBJECT SET TITLE(*; "btn_refresh"; "⏳ 更新中...")
	
	var $window : Integer:=Current form window
	CALL WORKER("weatherWorker"; Formula(_weatherWorkerJob($window)))
	
Function _onWeatherDone()
	This.running:=False
	//OBJECT SET TITLE(*; "btn_refresh"; "🌤 Refresh Weather")
	OBJECT SET TITLE(*; "btn_refresh"; "🌤 天気予報")
	This._loadEvents(This.activeFilter)
	