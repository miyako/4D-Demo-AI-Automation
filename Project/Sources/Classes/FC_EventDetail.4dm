// FC_EventDetail.4dm
// Scénario 2 : Alerte météo + panneau IA avec actions contextuelles

property event : cs.EventEntity
property eventLines : Collection
property aiActions : Collection
property confirmLines : Collection
property running : Boolean
property _eventIDs : Collection
property _currentIndex : Integer
property _pendingExecResult : Object
property _pendingAction : Object
property _pendingActionIndex : Integer
property _pendingVenueSwitchData : Object
property activeAdvisorTab : Text
property linkedEmail : cs.EmailEntity
property hasEmail : Boolean

Class constructor($event : cs.EventEntity; $eventIDs : Collection)
	This.event:=$event
	This.eventLines:=[]
	This.aiActions:=[]
	This.confirmLines:=[]
	This.running:=False
	This._pendingExecResult:=Null
	This._pendingAction:=Null
	This._pendingActionIndex:=-1
	This._pendingVenueSwitchData:=Null
	This.activeAdvisorTab:="weather"
	This.linkedEmail:=Null
	This.hasEmail:=False
	If ($eventIDs#Null)
		This._eventIDs:=$eventIDs
	Else 
		This._eventIDs:=[]
	End if 
	This._currentIndex:=This._eventIDs.indexOf($event.ID)

//MARK: - Form & form objects event handlers
Function formEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Load)
			This._onLoad()
	End case 

Function btnBackEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			CANCEL
	End case 

Function btnPrevEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._navigate(-1)
	End case 

Function btnNextEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._navigate(1)
	End case 

Function btnAiAnalyzeEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._runWeatherAnalysis()
	End case 

Function btnAiAction1EventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._executeAction(0)
	End case 

Function btnAiAction2EventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._executeAction(1)
	End case 

Function btnAiAction3EventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._executeAction(2)
	End case 

Function btnAiAction4EventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._executeAction(3)
	End case 

Function btnTabWeatherEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setAdvisorTab("weather")
	End case 

Function btnTabEmailEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setAdvisorTab("email")
	End case 

Function btnEmailAnalyzeEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._runEmailAnalysis()
	End case 

//MARK: - Private
Function _onLoad()
	This._resizeWindow(1100)
	This._populateHeader()
	This._loadEventLines()
	// Check for linked unread email
	var $emails : cs.EmailSelection:=ds.Email.query("linkedEventID = :1 AND emailStatus = :2"; String(This.event.ID); "unread")
	If ($emails.length>0)
		This.linkedEmail:=$emails.first()
		This.hasEmail:=True
		OBJECT SET VISIBLE(*; "btn_tab_email"; True)
	End if 
	This._renderAIPanel(Null)
	This._updateNavButtons()
	This._applyReadOnlyIfDone()

Function _populateHeader()
	var $evt : cs.EventEntity:=This.event
	var $client : cs.ClientEntity:=$evt.client
	var $venue : cs.VenueEntity:=$evt.venue

	OBJECT SET TITLE(*; "text_title"; "Event Detail")
	OBJECT SET TITLE(*; "text_ref"; $evt.contractRef)
	OBJECT SET TITLE(*; "text_client_val"; Choose($client#Null; $client.companyName; "—"))
	OBJECT SET TITLE(*; "text_contact_val"; Choose($client#Null; $client.contactName+" · "+$client.email; ""))
	OBJECT SET TITLE(*; "text_date_val"; String($evt.eventDate; "EEEE dd MMMM yyyy"))
	OBJECT SET TITLE(*; "text_guests_val"; String($evt.guestCount)+" guests")

	// Venue with separate indoor/outdoor indicator
	var $venueLabel : Text:=Choose($venue#Null; $venue.name+" – "+$venue.city+", "+$venue.country; "—")
	OBJECT SET TITLE(*; "text_venue_val"; $venueLabel)
	var $optionIcon : Text:=Choose($evt.venueOption="indoor"; "🏢 Indoor"; "🌳 Outdoor")
	OBJECT SET TITLE(*; "text_option_val"; $optionIcon)
	OBJECT SET TITLE(*; "text_status_val"; This._statusLabel($evt.status))
	OBJECT SET TITLE(*; "text_weather_badge"; This._weatherBadge($evt.weatherAlertLevel))

Function _loadEventLines()
	var $selection : cs.EventLineSelection:=ds.EventLine.query("eventID = :1"; This.event.ID)
	var $total : Real:=0
	This.eventLines:=[]
	var $line : cs.EventLineEntity
	var $service : cs.ServiceEntity
	var $lineTotal : Real
	For each ($line; $selection)
		$service:=$line.service
		$lineTotal:=$line.quantity*$line.unitPrice
		$total:=$total+$lineTotal
		This.eventLines.push({ \
			serviceLabel: Choose($service#Null; $service.label; "—"); \
			category: Choose($service#Null; $service.category; "—"); \
			quantity: $line.quantity; \
			unitPrice: $line.unitPrice; \
			quantityStr: String($line.quantity); \
			unitPriceStr: String($line.unitPrice; "### ### ##0 €"); \
			totalStr: String($lineTotal; "### ### ##0 €") \
		})
	End for each 

	// Add venue rental cost
	var $rentalPrice : Real:=This.event.venueRentalPrice
	If ($rentalPrice>0)
		$total:=$total+$rentalPrice
		OBJECT SET TITLE(*; "text_rental_val"; "Venue rental: "+String($rentalPrice; "### ### ##0 €"))
	Else 
		OBJECT SET TITLE(*; "text_rental_val"; "")
	End if 
	OBJECT SET TITLE(*; "text_total_val"; String($total; "### ### ##0 €"))

Function _renderAIPanel($weatherResult : Object)
	cs.UIHelpers.me.resetActionButtons()
	OBJECT SET TITLE(*; "text_ai_setup"; "")
	OBJECT SET TITLE(*; "text_ai_explanation"; "")

	// Show contracted and forecast weather
	var $setup : Object:=This.event.weatherSetup
	var $forecast : Object:=This.event.weatherForecast
	var $setupStr : Text:=""
	If ($setup#Null)
		$setupStr:="Planned: "+This._setupLabel($setup)
	End if 
	If ($forecast#Null)
		$setupStr:=$setupStr+"\nForecast: "+This._forecastLabel($forecast)
	End if 
	OBJECT SET TITLE(*; "text_ai_setup"; $setupStr) 

	If ($weatherResult=Null)
		var $level : Text:=This.event.weatherAlertLevel
		If (($level="none") || ($level=""))
			OBJECT SET TITLE(*; "text_ai_status"; "No weather alerts detected.")
			OBJECT SET TITLE(*; "text_ai_context"; "Click 'Run AI Weather Analysis' to analyze forecast for this event's venue.")
		Else 
			OBJECT SET TITLE(*; "text_ai_status"; "⚠ Weather alert: "+$level)
			OBJECT SET TITLE(*; "text_ai_context"; "Click 'Run AI Weather Analysis' to get AI-recommended actions.")
		End if 
		return 
	End if 

	If (Not($weatherResult.success))
		OBJECT SET TITLE(*; "text_ai_status"; "⚠ Analysis failed")
		OBJECT SET TITLE(*; "text_ai_context"; $weatherResult.validationError)
		return 
	End if 

	var $wa : Object:=$weatherResult.weatherActions
	OBJECT SET TITLE(*; "text_ai_status"; This._riskLabel($wa.riskLevel))
	OBJECT SET TITLE(*; "text_ai_context"; $wa.weatherSummary)

	// Afficher l'explication IA
	If (($wa.explanation#Null) && ($wa.explanation#""))
		OBJECT SET TITLE(*; "text_ai_explanation"; $wa.explanation)
	End if 

	OBJECT SET TITLE(*; "text_ai_validation_badge"; "✓ JSON Validate: schema_weather_actions OK")

	var $actions : Collection:=$wa.actions
	cs.UIHelpers.me.showActionButtons($actions)
	This.aiActions:=$actions

// ─── Tab management ───────────────────────────────────────────────────────────
Function _setAdvisorTab($tab : Text)
	This.activeAdvisorTab:=$tab
	cs.UIHelpers.me.resetActionButtons()
	This.aiActions:=[]

	var $isWeather : Boolean:=($tab="weather")
	// Weather tab controls
	OBJECT SET VISIBLE(*; "text_ai_status"; $isWeather)
	OBJECT SET VISIBLE(*; "text_ai_context"; $isWeather)
	OBJECT SET VISIBLE(*; "text_ai_setup"; $isWeather)
	OBJECT SET VISIBLE(*; "text_ai_explanation"; $isWeather)
	OBJECT SET VISIBLE(*; "btn_ai_analyze"; $isWeather)
	OBJECT SET VISIBLE(*; "text_ai_validation_badge"; $isWeather)
	// Email tab controls
	OBJECT SET VISIBLE(*; "text_email_meta"; Not($isWeather))
	OBJECT SET VISIBLE(*; "text_email_subject"; Not($isWeather))
	OBJECT SET VISIBLE(*; "input_email_body"; Not($isWeather))
	OBJECT SET VISIBLE(*; "text_email_ai_status"; Not($isWeather))
	OBJECT SET VISIBLE(*; "text_email_ai_result"; Not($isWeather))
	OBJECT SET VISIBLE(*; "btn_email_analyze"; Not($isWeather))
	// Tab button styles
	OBJECT SET STYLE SHEET(*; "btn_tab_weather"; Choose($isWeather; "btnFilterActive"; "btnFilterInactive"))
	OBJECT SET STYLE SHEET(*; "btn_tab_email"; Choose(Not($isWeather); "btnFilterActive"; "btnFilterInactive"))
	// Load email content if switching to email tab
	If (Not($isWeather) && (This.linkedEmail#Null))
		This._loadEmailTab()
	End if 

Function _loadEmailTab()
	var $e : cs.EmailEntity:=This.linkedEmail
	If ($e=Null)
		return 
	End if 
	var $meta : Text:="From: "+$e.sender+" <"+$e.senderEmail+">"
	$meta:=$meta+"\nReceived: "+String($e.receivedAt; "dd MMM yyyy")
	OBJECT SET TITLE(*; "text_email_meta"; $meta)
	OBJECT SET TITLE(*; "text_email_subject"; $e.subject)
	OBJECT SET VALUE("input_email_body"; $e.body)
	OBJECT SET TITLE(*; "text_email_ai_status"; "Click 'Analyze Email with AI' to process this request.")
	OBJECT SET TITLE(*; "text_email_ai_result"; "")

// ─── Email AI analysis ────────────────────────────────────────────────────────
Function _runEmailAnalysis()
	If (This.linkedEmail=Null)
		return 
	End if 
	This.running:=True
	OBJECT SET TITLE(*; "btn_email_analyze"; "⏳ Analyzing...")
	OBJECT SET TITLE(*; "text_email_ai_status"; "Analyzing modification request...")

	var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
	var $self : Object:=This
	$advisor.analyzeLinkedEmailAsync(This.linkedEmail; This.event; This.eventLines; Formula($self._onEmailAnalysisDone($1)))

Function _onEmailAnalysisDone($result : Object)
	If (Form=Null)
		return 
	End if 
	This.running:=False
	OBJECT SET TITLE(*; "btn_email_analyze"; "📧 Analyze Email with AI")

	If (Not($result.success))
		OBJECT SET TITLE(*; "text_email_ai_status"; "❌ Analysis failed")
		OBJECT SET TITLE(*; "text_email_ai_result"; $result.validationError)
		return 
	End if 

	var $impacts : Object:=$result.impacts
	OBJECT SET TITLE(*; "text_email_ai_status"; "✓ Modification request analyzed")

	// Build summary text
	var $summary : Text:=""
	If (($impacts.summary#Null) && ($impacts.summary#""))
		$summary:=$impacts.summary+"\n\n"
	End if 
	If (($impacts.impacts#Null) && ($impacts.impacts.length>0))
		$summary:=$summary+"Service changes:\n"
		var $imp : Object
		For each ($imp; $impacts.impacts)
			$summary:=$summary+"• "+String($imp.description)+"\n"
		End for each 
	End if 
	OBJECT SET TITLE(*; "text_email_ai_result"; $summary)

	// Show execution actions
	If (($impacts.executionActions#Null) && ($impacts.executionActions.length>0))
		cs.UIHelpers.me.showActionButtons($impacts.executionActions)
		This.aiActions:=$impacts.executionActions
	End if 

Function _runWeatherAnalysis()
	This.running:=True
	OBJECT SET TITLE(*; "btn_ai_analyze"; "⏳ Analyzing...")
	OBJECT SET TITLE(*; "text_ai_status"; "Fetching weather data...")

	var $weather : cs.WeatherService:=cs.WeatherService.me
	var $weatherFetch : Object:=$weather.fetchForEvent(This.event)

	// Store rationalized forecast and compute alert by comparison
	If ($weatherFetch.success)
		This.event.weatherForecast:=$weatherFetch.rationalized
		This.event.weatherAlertLevel:=$weather.compareWeather(This.event.weatherSetup; $weatherFetch.rationalized; This.event.venueOption)
		This.event.weatherAlertJson:=JSON Parse(JSON Stringify($weatherFetch))
	Else 
		This.event.weatherAlertLevel:="none"
	End if 
	This.event.save()

	OBJECT SET TITLE(*; "text_ai_status"; "Asking AI for recommendations...")

	var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
	var $self : Object:=This
	var $wf : Object:=$weatherFetch
	$advisor.analyzeWeatherRiskAsync(This.event; $weatherFetch.weatherData; This.eventLines; Formula($self._onWeatherAnalysisDone($1; $wf)))

// ─── Callbacks async ─────────────────────────────────────────────────────────
Function _onWeatherAnalysisDone($aiResult : Object; $weatherFetch : Object)
	If (Form=Null)
		return 
	End if 
	OBJECT SET TITLE(*; "text_weather_badge"; This._weatherBadge($weatherFetch.riskLevel))
	This.running:=False
	OBJECT SET TITLE(*; "btn_ai_analyze"; "⚡ Run AI Weather Analysis")
	This._renderAIPanel($aiResult)

Function _executeAction($index : Integer)
	If ($index>=This.aiActions.length)
		return 
	End if 
	var $action : Object:=This.aiActions[$index]
	var $type : Text:=$action.actionType
	This._pendingActionIndex:=$index

	// switch_venue is handled locally — no AI tool calling needed
	If ($type="switch_venue")
		This._executeSwitchVenue($action)
		return 
	End if 

	// Si l'action a un hiddenPrompt, utiliser le Temps 2 (tool calling)
	If (($action.hiddenPrompt#Null) && ($action.hiddenPrompt#""))
		This._executeWithToolCalling($action)
		return 
	End if 

	// Fallback pour les actions sans hiddenPrompt
	Case of 
		: ($type="notify_client")
			var $draft : Text:=Choose(($action.description#Null); $action.description; "")
			ALERT("Draft message to client:\n\n"+$draft)
		: ($type="monitor")
			ALERT("Monitoring set. Weather will be re-checked automatically.")
		Else 
			ALERT("Action: "+$action.label+"\n\n"+Choose(($action.description#Null); $action.description; ""))
	End case 

// ─── Temps 2 : Exécution avec tool calling + dialogue confirmation ───────────
Function _executeWithToolCalling($action : Object)
	OBJECT SET TITLE(*; "text_ai_status"; "⏳ Searching services...")

	// Contexte de l'événement
	var $context : Object:={ \
		eventID: This.event.ID; \
		eventDate: String(This.event.eventDate; "yyyy-MM-dd"); \
		guestCount: This.event.guestCount; \
		venueName: This.event.venue.name \
	}

	// Lignes existantes
	$context.existingLines:=[]
	var $line : Object
	For each ($line; This.eventLines)
		$context.existingLines.push({ \
			serviceID: $line.serviceID; \
			serviceLabel: $line.serviceLabel; \
			quantity: $line.quantity; \
			unitPrice: $line.unitPrice \
		})
	End for each 

	var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
	var $self : Object:=This
	var $act : Object:=$action
	$advisor.executeActionAsync($action.hiddenPrompt; $context; Formula($self._onExecutionDone($1; $act)))

Function _onExecutionDone($execResult : Object; $action : Object)
	If (Form=Null)
		return 
	End if 

	If (Not($execResult.success))
		OBJECT SET TITLE(*; "text_ai_status"; "❌ "+$execResult.error)
		return 
	End if 

	If (($execResult.proposedLines=Null) || ($execResult.proposedLines.length=0))
		var $reason : Text:=Choose(($execResult.summary#Null) && ($execResult.summary#""); $execResult.summary; "No matching service found in catalog.")
		OBJECT SET TITLE(*; "text_ai_status"; "⚠ "+$reason)
		return 
	End if 

	// Safety: if ALL lines are 'remove' with no 'add' lines → hallucination, abort
	var $hasAdd : Boolean:=False
	var $hasNonRemove : Boolean:=False
	var $pl2 : Object
	For each ($pl2; $execResult.proposedLines)
		If ($pl2.delta="add") | ($pl2.delta="update")
			$hasAdd:=True
			$hasNonRemove:=True
		End if 
	End for each 
	If (Not($hasAdd))
		// Only removes proposed for what was supposed to be an add/replace — abort
		If ($action.actionType="add_services")
			var $reason2 : Text:=Choose(($execResult.summary#Null) && ($execResult.summary#""); $execResult.summary; "Service not available in catalog.")
			OBJECT SET TITLE(*; "text_ai_status"; "⚠ "+$reason2)
			return 
		End if 
	End if 

	// Safety: remove any 'add' lines whose label also appears in a 'remove' line
	var $removeLabels : Collection:=[]
	var $pl : Object
	For each ($pl; $execResult.proposedLines)
		If ($pl.delta="remove")
			$removeLabels.push(Lowercase($pl.label))
		End if 
	End for each 
	If ($removeLabels.length>0)
		var $cleanLines : Collection:=[]
		For each ($pl; $execResult.proposedLines)
			If (Not(($pl.delta="add") && $removeLabels.includes(Lowercase($pl.label))))
				$cleanLines.push($pl)
			End if 
		End for each 
		$execResult.proposedLines:=$cleanLines
	End if 

	OBJECT SET TITLE(*; "text_ai_status"; "")
	This._showConfirmPanel($action; $execResult)

// ─── switch_venue : handled locally, no AI needed ────────────────────────────
Function _executeSwitchVenue($action : Object)
	var $venue : cs.VenueEntity:=This.event.venue
	If (($venue=Null) || ($venue.indoorOption=Null))
		OBJECT SET TITLE(*; "text_ai_status"; "❌ No indoor option available at this venue.")
		return 
	End if 
	var $oldRental : Real:=This.event.venueRentalPrice
	var $newRental : Real:=Num($venue.indoorOption.rentalPrice)
	var $rentalDelta : Real:=$newRental-$oldRental
	// Store for commit in btnConfirmActionEventHandler
	This._pendingVenueSwitchData:={ \
		newOption: "indoor"; \
		newRentalPrice: $newRental; \
		oldRentalPrice: $oldRental; \
		venueName: $venue.indoorOption.name \
	}
	// Build synthetic execResult for the confirm panel
	var $execResult : Object:={proposedLines: []; summary: "Switch to indoor venue '"+$venue.indoorOption.name+"' (capacity: "+String(Num($venue.indoorOption.capacity))+"). Weather risk will be eliminated."}
	$execResult.proposedLines.push({ \
		label: "Switch to indoor: "+$venue.indoorOption.name; \
		quantity: 1; \
		unitPrice: $rentalDelta; \
		delta: "venue_switch" \
	})
	This._showConfirmPanel($action; $execResult)

Function _showConfirmPanel($action : Object; $execResult : Object)
	This._pendingAction:=$action
	This._pendingExecResult:=$execResult

	var $currentTotal : Real:=cs.EventLineService.me.calculateTotal(This.eventLines)
	This.confirmLines:=[]
	var $impact : Real:=0
	var $line : Object
	For each ($line; $execResult.proposedLines)
		var $lineTotal : Real:=$line.quantity*$line.unitPrice
		var $deltaIcon : Text
		Case of 
			: ($line.delta="add")
				$deltaIcon:="+"
				$impact:=$impact+$lineTotal
			: ($line.delta="remove")
				$deltaIcon:="—"
				$impact:=$impact-$lineTotal
				$lineTotal:=-$lineTotal
			: ($line.delta="update")
				$deltaIcon:="✏"
				$impact:=$impact+$lineTotal
			: ($line.delta="venue_switch")
				$deltaIcon:="🏢"
				$impact:=$impact+$lineTotal
		End case 
		This.confirmLines.push({ \
			label: $line.label; \
			quantity: $line.quantity; \
			deltaIcon: $deltaIcon; \
			lineTotalDisplay: String(Abs($lineTotal); "### ### ##0 €") \
		})
	End for each 

	var $prefix : Text:=Choose($impact>=0; "+"; "")
	OBJECT SET TITLE(*; "text_confirm_title"; $action.label)
	OBJECT SET TITLE(*; "text_confirm_summary"; $execResult.summary)
	OBJECT SET TITLE(*; "text_confirm_impact_val"; $prefix+String($impact; "### ### ##0 €"))
	OBJECT SET TITLE(*; "text_confirm_newtotal_val"; String($currentTotal+$impact; "### ### ##0 €"))
	This._setConfirmPanelVisible(True)
	This._resizeWindow(1460)

Function _hideConfirmPanel()
	This._setConfirmPanelVisible(False)
	This._resizeWindow(1100)
	This._pendingExecResult:=Null
	This._pendingAction:=Null
	This._pendingActionIndex:=-1
	This._pendingVenueSwitchData:=Null

Function _resizeWindow($width : Integer)
	var $curL; $curT; $curR; $curB : Integer
	GET WINDOW RECT($curL; $curT; $curR; $curB; Current form window)
	var $height : Integer:=$curB-$curT
	// Detect which screen the window is currently on
	var $screenL; $screenT; $screenR; $screenB : Integer
	var $sL; $sT; $sR; $sB : Integer
	var $i : Integer
	$screenL:=0
	$screenT:=0
	$screenR:=0
	$screenB:=0
	For ($i; 1; Count screens)
		SCREEN COORDINATES($sL; $sT; $sR; $sB; $i)
		If (($curL>=$sL) && ($curL<$sR))
			$screenL:=$sL
			$screenT:=$sT
			$screenR:=$sR
			$screenB:=$sB
		End if 
	End for 
	If ($screenR=$screenL)
		// Fallback to main screen
		SCREEN COORDINATES($screenL; $screenT; $screenR; $screenB)
	End if 
	// Clamp to detected screen so window doesn't go off-screen
	If (($curL+$width)>$screenR)
		$curL:=$screenR-$width
		If ($curL<$screenL)
			$curL:=$screenL
		End if 
	End if 
	SET WINDOW RECT($curL; $curT; $curL+$width; $curT+$height; Current form window)

Function _setConfirmPanelVisible($visible : Boolean)
	OBJECT SET VISIBLE(*; "rect_confirm_header_bg"; $visible)
	OBJECT SET VISIBLE(*; "rect_confirm_sep"; $visible)
	OBJECT SET VISIBLE(*; "rect_confirm_bg"; $visible)
	OBJECT SET VISIBLE(*; "rect_confirm_divider"; $visible)
	OBJECT SET VISIBLE(*; "text_confirm_header"; $visible)
	OBJECT SET VISIBLE(*; "text_confirm_title"; $visible)
	OBJECT SET VISIBLE(*; "text_confirm_summary"; $visible)
	OBJECT SET VISIBLE(*; "listbox_confirm"; $visible)
	OBJECT SET VISIBLE(*; "rect_confirm_footer_sep"; $visible)
	OBJECT SET VISIBLE(*; "text_confirm_impact_lbl"; $visible)
	OBJECT SET VISIBLE(*; "text_confirm_impact_val"; $visible)
	OBJECT SET VISIBLE(*; "text_confirm_newtotal_lbl"; $visible)
	OBJECT SET VISIBLE(*; "text_confirm_newtotal_val"; $visible)
	OBJECT SET VISIBLE(*; "btn_cancel_confirm"; $visible)
	OBJECT SET VISIBLE(*; "btn_confirm_action"; $visible)

Function btnConfirmActionEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			// Route venue switch separately
			If (This._pendingVenueSwitchData#Null)
				This._applyVenueSwitch()
				return 
			End if 
			If (This._pendingExecResult=Null)
				return 
			End if 
			// 1. Remember which action index was confirmed before hide clears it
			var $confirmedIndex : Integer:=This._pendingActionIndex
			// 2. Apply service changes to DB
			cs.EventLineService.me.applyProposedChanges(This.event.ID; This._pendingExecResult.proposedLines)
			// 3. Hide panel and reload lines
			This._hideConfirmPanel()
			This._loadEventLines()
			// 4. Re-assess effective planned weather from updated service list
			This._reassessEventSetup()
			// 5. Remove the confirmed action button from the action list
			If (($confirmedIndex>=0) && ($confirmedIndex<This.aiActions.length))
				This.aiActions.remove($confirmedIndex; 1)
			End if 
			// 6. Re-render remaining action buttons
			cs.UIHelpers.me.resetActionButtons()
			cs.UIHelpers.me.showActionButtons(This.aiActions)
			OBJECT SET TITLE(*; "text_ai_status"; "✅ Action applied. Event setup re-assessed.")
	End case 

Function btnCancelConfirmEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._hideConfirmPanel()
			OBJECT SET TITLE(*; "text_ai_status"; "Action cancelled.")
	End case 

// Re-assess the event's effective planned weatherSetup based on current service lines.
// Updates weatherSetup.conditions, recomputes alertLevel, saves, and refreshes UI.
Function _reassessEventSetup()
	var $setup : Object:=This.event.weatherSetup
	If ($setup=Null)
		return 
	End if 
	var $weather : cs.WeatherService:=cs.WeatherService.me
	var $newConditions : Text:=$weather.assessSetupFromLines(This.eventLines; $setup.conditions)
	If ($newConditions="")
		return  // indoor/indifferent: no change
	End if 
	If ($setup.conditions=$newConditions)
		return  // already correct
	End if 
	// Update conditions in the stored setup object
	$setup.conditions:=$newConditions
	This.event.weatherSetup:=$setup
	// Recompute alert level against current forecast
	If (This.event.weatherForecast#Null)
		This.event.weatherAlertLevel:=$weather.compareWeather($setup; This.event.weatherForecast; This.event.venueOption)
	Else 
		This.event.weatherAlertLevel:="none"
	End if 
	This.event.save()
	// Refresh header badge and setup/forecast display
	OBJECT SET TITLE(*; "text_weather_badge"; This._weatherBadge(This.event.weatherAlertLevel))
	This._updateSetupDisplay()

// Refresh only the planned/forecast labels in the AI panel (without clearing explanation/actions).
Function _updateSetupDisplay()
	var $setup : Object:=This.event.weatherSetup
	var $forecast : Object:=This.event.weatherForecast
	var $setupStr : Text:=""
	If ($setup#Null)
		$setupStr:="Planned: "+This._setupLabel($setup)
	End if 
	If ($forecast#Null)
		$setupStr:=$setupStr+"\nForecast: "+This._forecastLabel($forecast)
	End if 
	OBJECT SET TITLE(*; "text_ai_setup"; $setupStr)

// Apply the pending venue switch: updates event entity and refreshes UI.
Function _applyVenueSwitch()
	var $data : Object:=This._pendingVenueSwitchData
	var $confirmedIndex : Integer:=This._pendingActionIndex
	// Update event fields
	This.event.venueOption:="indoor"
	This.event.venueRentalPrice:=$data.newRentalPrice
	// Indoor event: weather becomes indifferent, no alert
	var $setup : Object:=This.event.weatherSetup
	If ($setup#Null)
		$setup.conditions:="indifferent"
		$setup.temperature:="normal"
		This.event.weatherSetup:=$setup
	End if 
	This.event.weatherAlertLevel:="none"
	This.event.save()

	// Remove outdoor-specific services no longer needed indoors
	This._removeOutdoorServicesAfterIndoorSwitch()

	// Hide confirm panel (resets _pendingVenueSwitchData and _pendingActionIndex)
	This._hideConfirmPanel()
	// Refresh UI
	This._populateHeader()
	This._loadEventLines()
	This._updateSetupDisplay()
	OBJECT SET TITLE(*; "text_weather_badge"; This._weatherBadge("none"))
	// Remove confirmed action button
	If (($confirmedIndex>=0) && ($confirmedIndex<This.aiActions.length))
		This.aiActions.remove($confirmedIndex; 1)
	End if 
	cs.UIHelpers.me.resetActionButtons()
	cs.UIHelpers.me.showActionButtons(This.aiActions)
	OBJECT SET TITLE(*; "text_ai_status"; "✅ Switched to indoor venue. Outdoor services removed.")

// ─── Remove outdoor-specific services after an indoor venue switch ────────────
Function _removeOutdoorServicesAfterIndoorSwitch()
	// Categories and label patterns that are only needed outdoors
	var $outdoorCategories : Collection:=["Structures"]
	var $outdoorLabelPatterns : Collection:=[\
		"extérieure"; "outdoor"; "tent"; "marquee"; "pagoda"; "stretch"; \
		"patio heater"; "umbrella"; "poncho"; "air conditioning"; "hot air heater"; \
		"generator"; "outdoor sound"\
	]

	var $lines : cs.EventLineSelection:=ds.EventLine.query("eventID = :1"; This.event.ID)
	var $line : cs.EventLineEntity
	For each ($line; $lines)
		var $svc : cs.ServiceEntity:=ds.Service.get($line.serviceID)
		If ($svc#Null)
			var $shouldRemove : Boolean:=False
			// Remove all Structures (tents, stages are outdoor only)
			If ($outdoorCategories.indexOf($svc.category)>=0)
				$shouldRemove:=True
			End if 
			// Remove by label pattern
			If (Not($shouldRemove))
				var $lbl : Text:=Lowercase($svc.label)
				var $pattern : Text
				For each ($pattern; $outdoorLabelPatterns)
					If (Position($pattern; $lbl)>0)
						$shouldRemove:=True
					End if 
				End for each 
			End if 
			If ($shouldRemove)
				$line.drop()
			End if 
		End if 
	End for each 


Function _weatherBadge($level : Text) : Text
	Case of 
		: ($level="critical")
			return "🚨 CRITICAL WEATHER"
		: ($level="warning")
			return "⛈ Weather Warning"
		: ($level="watch")
			return "🌧 Weather Watch"
		Else 
			return "☀ Clear forecast"
	End case 

Function _riskLabel($level : Text) : Text
	Case of 
		: ($level="critical")
			return "🚨 Critical risk – action required"
		: ($level="warning")
			return "⛈ Weather warning for event day"
		: ($level="watch")
			return "🌧 Weather watch – monitor closely"
		Else 
			return "☀ No significant weather risk"
	End case 

Function _statusLabel($status : Text) : Text
	Case of 
		: ($status="confirmed")
			return "✅ Confirmed"
		: ($status="quote")
			return "💬 Quote"
		: ($status="completed")
			return "✔ Completed"
		: ($status="cancelled")
			return "❌ Cancelled"
		Else 
			return $status
	End case 

Function _setupLabel($setup : Object) : Text
	var $cond : Text
	Case of 
		: ($setup.conditions="indifferent")
			$cond:="🏢 Indoor"
		: ($setup.conditions="rain")
			$cond:="🌧 Rain-ready"
		: ($setup.conditions="sunny")
			$cond:="☀ Fair weather"
		Else 
			$cond:=$setup.conditions
	End case 
	var $temp : Text
	Case of 
		: ($setup.temperature="cold")
			$temp:="❄ Cold"
		: ($setup.temperature="hot")
			$temp:="🔥 Hot"
		Else 
			$temp:="🌡 Normal temp"
	End case 
	return $cond+" · "+$temp

Function _forecastLabel($forecast : Object) : Text
	var $cond : Text
	Case of 
		: ($forecast.conditions="rain")
			$cond:="🌧 Rain expected"
		: ($forecast.conditions="sunny")
			$cond:="☀ Sunny"
		: ($forecast.conditions="indifferent")
			$cond:="🏢 Indoor"
		Else 
			$cond:=$forecast.conditions
	End case 
	var $temp : Text
	Case of 
		: ($forecast.temperature="cold")
			$temp:="❄ Cold"
		: ($forecast.temperature="hot")
			$temp:="🔥 Hot"
		Else 
			$temp:="🌡 Normal temp"
	End case 
	return $cond+" · "+$temp

Function _navigate($direction : Integer)
	If (This._eventIDs.length=0)
		return 
	End if 
	var $newIndex : Integer:=This._currentIndex+$direction
	If (($newIndex<0) || ($newIndex>=This._eventIDs.length))
		return 
	End if 
	var $newEvent : cs.EventEntity:=ds.Event.get(This._eventIDs[$newIndex])
	If ($newEvent=Null)
		return 
	End if 
	This.event:=$newEvent
	This._currentIndex:=$newIndex
	This.aiActions:=[]
	If (This._pendingExecResult#Null)
		This._hideConfirmPanel()
	End if 
	This._populateHeader()
	This._loadEventLines()
	This._renderAIPanel(Null)
	This._updateNavButtons()
	This._applyReadOnlyIfDone()

Function _updateNavButtons()
	var $lastIndex : Integer:=This._eventIDs.length-1
	var $hasPrev : Boolean:=(This._currentIndex>0)
	var $hasNext : Boolean:=(This._currentIndex<$lastIndex)
	OBJECT SET ENABLED(*; "btn_prev"; $hasPrev)
	OBJECT SET ENABLED(*; "btn_next"; $hasNext)

Function _applyReadOnlyIfDone()
	var $isDone : Boolean:=((This.event.status="completed") || (This.event.status="cancelled"))
	OBJECT SET ENABLED(*; "btn_ai_analyze"; Not($isDone))
	OBJECT SET ENABLED(*; "btn_ai_action1"; Not($isDone))
	OBJECT SET ENABLED(*; "btn_ai_action2"; Not($isDone))
	OBJECT SET ENABLED(*; "btn_ai_action3"; Not($isDone))
	OBJECT SET ENABLED(*; "btn_ai_action4"; Not($isDone))
	If ($isDone)
		OBJECT SET TITLE(*; "text_ai_status"; "This event is "+This.event.status+" and cannot be modified.")
		OBJECT SET TITLE(*; "text_ai_context"; "")
	End if 
