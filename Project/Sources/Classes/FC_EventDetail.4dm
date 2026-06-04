// FC_EventDetail.4dm
// Scenario 2: Weather alert + AI panel with contextual actions

property event : cs.EventEntity
property eventLines : cs.EventLineSelection
property currentLine : cs.EventLineEntity
property aiActions : Collection
property confirmDraft : Text
property confirmEmailDraft : Text
property confirmLines : Collection
property running : Boolean
property _spinnerIndex : Integer
property _spinnerFrames : Collection
property _spinnerActive : Boolean
property _selection : cs.EventSelection
property _pendingExecResult : Object
property _pendingAction : Object
property activeAdvisorTab : Text
property linkedEmail : cs.EmailEntity
property hasEmail : Boolean
property tabControl : Object
property _lastValidationData : Object
property _actionMap : Collection
property _emailImpacts : Object
property _listFC : Object

Class constructor($event : cs.EventEntity; $eventSelection : cs.EventSelection; $listFC : Object)
	This.event:=$event
	This.eventLines:=ds.EventLine.newSelection()
	This.currentLine:=Null
	This.aiActions:=[]
	This.confirmDraft:=""
	This.confirmEmailDraft:=""
	This.confirmLines:=[]
	This.running:=False
	This._spinnerIndex:=0
	This._spinnerFrames:=["⠋"; "⠙"; "⠹"; "⠸"; "⠼"; "⠴"; "⠦"; "⠧"; "⠇"; "⠏"]
	This._spinnerActive:=False
	This._pendingExecResult:=Null
	This._pendingAction:=Null
	This.activeAdvisorTab:="weather"
	This.linkedEmail:=Null
	This.hasEmail:=False
	This.tabControl:=New object("values"; New collection("⛅ Weather"; "📧 Email"); "index"; 0)
	This._lastValidationData:=Null
	This._actionMap:=[-1; -1; -1; -1]
	This._emailImpacts:=Null
	If ($eventSelection#Null)
		This._selection:=$eventSelection
	Else 
		This._selection:=ds.Event.newSelection()
	End if 
	This._listFC:=$listFC
	
	//MARK: - Form & form objects event handlers
Function formEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Load)
			This._onLoad()
		: ($formEventCode=On Timer)
			If (This._spinnerActive)
				This._spinnerIndex:=(This._spinnerIndex+1)%(This._spinnerFrames.length)
				OBJECT SET TITLE(*; "text_ai_spinner"; This._spinnerFrames[This._spinnerIndex])
			End if 
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
	
Function advisorTabsEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			If (Form.tabControl.index=0)
				This._setAdvisorTab("weather")
			Else 
				This._setAdvisorTab("email")
			End if 
	End case 
	
Function validationBadgeClicked()
	If (This._lastValidationData=Null)
		return 
	End if 
	var $d : Object:=This._lastValidationData
	var $schemaFile : 4D.File:=Folder(fk resources folder).file("schemas/"+$d.schema)
	var $fc : cs.FC_JSONValidateDetail:=cs.FC_JSONValidateDetail.new($d.schema; $schemaFile; $d.json)
	var $w : Integer:=Open form window("JSONValidateDetail"; Plain form window; Horizontally centered; Vertically centered)
	DIALOG("JSONValidateDetail"; $fc)
	CLOSE WINDOW($w)
	
Function _showValidationBadge($schemaName : Text; $validatedObject : Object)
	var $label : Text:=Replace string($schemaName; ".json"; "")
	OBJECT SET TITLE(*; "text_ai_validation_badge"; "✓ JSON Validate: "+$label)
	OBJECT SET VISIBLE(*; "text_ai_validation_badge"; True)
	This._lastValidationData:=New object("schema"; $schemaName; "json"; $validatedObject)
	
	//MARK: - Private
Function _onLoad()
	This._resizeWindow(1100)
	This._loadEventLines()
	This._checkLinkedEmail()
	This._renderCurrentTab()
	This._updateNavButtons()
	This._applyReadOnlyIfDone()
	
Function _loadEventLines()
	This.eventLines:=ds.EventLine.query("eventID = :1"; This.event.ID)
	
	// Compute total (lines + venue rental)
	var $total : Real:=0
	var $line : cs.EventLineEntity
	For each ($line; This.eventLines)
		$total:=$total+$line.lineTotal
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
	
Function _clearAIPanel()
	cs.UIHelpers.me.resetActionButtons()
	This.aiActions:=[]
	This._lastValidationData:=Null
	OBJECT SET TITLE(*; "text_ai_context"; "")
	OBJECT SET TITLE(*; "text_ai_status"; "")
	OBJECT SET TITLE(*; "text_weather_ai_explanation"; "")
	OBJECT SET TITLE(*; "text_email_ai_result"; "")
	OBJECT SET VISIBLE(*; "text_ai_validation_badge"; False)
	// Hide all tab-specific controls
	OBJECT SET VISIBLE(*; "btn_ai_analyze"; False)
	OBJECT SET VISIBLE(*; "text_weather_ai_explanation"; False)
	OBJECT SET VISIBLE(*; "input_email_body"; False)
	OBJECT SET VISIBLE(*; "text_email_ai_result"; False)
	OBJECT SET VISIBLE(*; "btn_email_analyze"; False)
	
Function _renderCurrentTab()
	This._clearAIPanel()
	If (This.activeAdvisorTab="email")
		This._renderEmailTab()
	Else 
		This._renderWeatherTab(Null)
	End if 
	
Function _renderWeatherTab($weatherResult : Object)
	OBJECT SET VISIBLE(*; "text_weather_ai_explanation"; True)
	
	// Show contracted and forecast weather in context
	var $setup : Object:=This.event.weatherSetup
	var $forecast : Object:=This.event.weatherForecast
	var $setupStr : Text:=""
	If ($setup#Null)
		$setupStr:="Planned: "+This.event.setupLabel
	End if 
	If ($forecast#Null)
		$setupStr:=$setupStr+"\nForecast: "+This.event.forecastLabel
	End if 
	OBJECT SET TITLE(*; "text_ai_context"; $setupStr)
	
	If ($weatherResult=Null)
		var $level : Text:=This.event.weatherAlertLevel
		var $hasAlert : Boolean:=(($level#"none") && ($level#""))
		If ($hasAlert)
			OBJECT SET TITLE(*; "text_ai_status"; "⚠ Weather alert: "+$level)
			OBJECT SET VISIBLE(*; "btn_ai_analyze"; True)
		Else 
			OBJECT SET TITLE(*; "text_ai_status"; "No weather alerts detected.")
			OBJECT SET VISIBLE(*; "btn_ai_analyze"; False)
		End if 
		return 
	End if 
	
	If (Not($weatherResult.success))
		OBJECT SET TITLE(*; "text_ai_status"; "⚠ Analysis failed: "+$weatherResult.validationError)
		return 
	End if 
	
	var $wa : Object:=$weatherResult.weatherActions
	OBJECT SET TITLE(*; "text_ai_status"; This.event.riskLabel)
	
	If (($wa.explanation#Null) && ($wa.explanation#""))
		OBJECT SET TITLE(*; "text_weather_ai_explanation"; $wa.explanation)
	End if 
	
	This._showValidationBadge("schema_weather_actions.json"; $weatherResult.weatherActions)
	
	var $actions : Collection:=$wa.actions
	This._actionMap:=cs.UIHelpers.me.showActionButtons($actions)
	This.aiActions:=$actions
	
Function _renderEmailTab()
	var $hasEmail : Boolean:=(This.linkedEmail#Null)
	OBJECT SET VISIBLE(*; "text_email_ai_result"; True)
	OBJECT SET VISIBLE(*; "input_email_body"; $hasEmail)
	OBJECT SET VISIBLE(*; "btn_email_analyze"; $hasEmail)
	If ($hasEmail)
		var $e : cs.EmailEntity:=This.linkedEmail
		var $meta : Text:="Subject: "+$e.subject+"\nFrom: "+$e.sender+" <"+$e.senderEmail+">\nReceived: "+String($e.receivedAt; "dd MMM yyyy")
		OBJECT SET TITLE(*; "text_ai_context"; $meta)
		OBJECT SET VALUE("input_email_body"; $e.body)
		OBJECT SET TITLE(*; "text_email_ai_result"; "")
		OBJECT SET TITLE(*; "text_ai_status"; "📧 Email pending")
	Else 
		OBJECT SET TITLE(*; "text_ai_context"; "No pending email for this event.")
		OBJECT SET TITLE(*; "text_ai_status"; "No email to process.")
	End if 
	
Function _runWeatherAnalysis()
	This.running:=True
	This._startSpinner()
	OBJECT SET VISIBLE(*; "btn_ai_analyze"; False)
	If (This._pendingExecResult#Null)
		This._hideConfirmPanel()
	End if 
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
	
	var $w : Integer:=Current form window
	var $wfJson : Text:=JSON Stringify($weatherFetch)
	var $linesJson : Text:=JSON Stringify(This._linesAsCollection())
	var $evtID : Text:=This.event.ID
	CALL WORKER("aiAdvisorWorker_"+String($w); Formula(_aiWeatherWorkerJob($w; $evtID; $wfJson; $linesJson)))
	
	// ─── Callbacks async ─────────────────────────────────────────────────────────
Function _onWeatherAnalysisDone($aiResult : Object; $weatherFetch : Object)
	If (Form=Null)
		return 
	End if 
	This.running:=False
	This._stopSpinner()
	OBJECT SET VISIBLE(*; "btn_ai_analyze"; True)
	OBJECT SET TITLE(*; "btn_ai_analyze"; "⚡ Run AI Weather Analysis")
	This._clearAIPanel()
	OBJECT SET VISIBLE(*; "text_weather_ai_explanation"; True)
	This._renderWeatherTab($aiResult)
	
	// ─── Tab management ───────────────────────────────────────────────────────────
Function _checkLinkedEmail()
	var $emails : cs.EmailSelection:=ds.Email.query("linkedEventID = :1 AND emailStatus = :2"; String(This.event.ID); "pending")
	If ($emails.length>0)
		This.linkedEmail:=$emails.first()
		This.hasEmail:=True
	Else 
		This.linkedEmail:=Null
		This.hasEmail:=False
	End if 
	
Function _setAdvisorTab($tab : Text)
	This.activeAdvisorTab:=$tab
	This._renderCurrentTab()
	
	// ─── Email AI analysis ────────────────────────────────────────────────────────
Function btnEmailAnalyzeEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._runEmailAnalysis()
	End case 
	
Function _runEmailAnalysis()
	If (This.linkedEmail=Null)
		return 
	End if 
	This.running:=True
	This._startSpinner()
	OBJECT SET VISIBLE(*; "btn_email_analyze"; False)
	If (This._pendingExecResult#Null)
		This._hideConfirmPanel()
	End if 
	OBJECT SET TITLE(*; "text_ai_status"; "⏳ Analyzing modification request...")
	
	var $evt : cs.EventEntity:=This.event
	var $w : Integer:=Current form window
	var $emailID : Text:=This.linkedEmail.ID
	var $eventID : Text:=String($evt.ID)
	var $linesJson : Text:=JSON Stringify(This._linesAsCollection())
	CALL WORKER("aiAdvisorWorker_"+String($w); Formula(_aiEmailWorkerJob($w; $emailID; $eventID; $linesJson)))
	
Function _onEmailAnalysisDone($result : Object)
	If (Form=Null)
		return 
	End if 
	This.running:=False
	This._stopSpinner()
	OBJECT SET VISIBLE(*; "btn_email_analyze"; True)
	OBJECT SET TITLE(*; "btn_email_analyze"; "📧 Analyze Email with AI")
	
	If (Not($result.success))
		OBJECT SET TITLE(*; "text_ai_status"; "❌ Email analysis failed")
		OBJECT SET TITLE(*; "text_email_ai_result"; $result.validationError ? $result.validationError : "Analysis failed")
		return 
	End if 
	
	var $impacts : Object:=$result.impacts
	This._emailImpacts:=$impacts
	OBJECT SET TITLE(*; "text_ai_status"; "✓ Modification request analyzed")
	This._showValidationBadge("schema_modification_impacts.json"; $impacts)
	
	var $summary : Text:=""
	If (($impacts.modificationSummary#Null) && ($impacts.modificationSummary#""))
		$summary:=$impacts.modificationSummary+"\n\n"
	End if 
	If (($impacts.impacts#Null) && ($impacts.impacts.length>0))
		$summary:=$summary+"Service changes:\n"
		var $imp : Object
		For each ($imp; $impacts.impacts)
			$summary:=$summary+"• "+String($imp.label)+"\n"
		End for each 
	End if 
	OBJECT SET TITLE(*; "text_email_ai_result"; $summary)
	
	If (($impacts.executionActions#Null) && ($impacts.executionActions.length>0))
		This._actionMap:=cs.UIHelpers.me.showActionButtons($impacts.executionActions)
		This.aiActions:=$impacts.executionActions
		// Hide analyze button once actions are proposed — user cannot re-trigger analysis
		OBJECT SET VISIBLE(*; "btn_email_analyze"; False)
	End if 
	
Function _executeAction($slot : Integer)
	var $actionIdx : Integer:=This._actionMap[$slot]
	If (($actionIdx<0) || ($actionIdx>=This.aiActions.length))
		return 
	End if 
	var $action : Object:=This.aiActions[$actionIdx]
	var $type : Text:=$action.actionType
	
	// switch_venue: update venueOption and rental price directly — no AI tool call needed
	If ($type="switch_venue")
		This._executeSwitchVenue($action)
		return 
	End if 
	
	// If the action has a hiddenPrompt, use tool calling (Step 2)
	If (($action.hiddenPrompt#Null) && ($action.hiddenPrompt#""))
		OBJECT SET TITLE(*; "text_ai_status"; "⏳ "+String($action.label)+"...")
		This._executeWithToolCalling($action)
		return 
	End if 
	
	// Fallback pour les actions sans hiddenPrompt
	Case of 
		: ($type="monitor")
			ALERT("Monitoring set. Weather will be re-checked automatically.")
		Else 
			ALERT("Action: "+$action.label+"\n\n"+($action.description || ""))
	End case 
	
	// ─── Step 2: Execution with tool calling + confirmation dialog ──────────────────
// $promptOverride: optional — if provided, replaces the action's hiddenPrompt
Function _executeWithToolCalling($action : Object; $promptOverride : Text)
	OBJECT SET TITLE(*; "text_ai_status"; "⏳ Searching services...")
	
	// Event context — use _linesAsCollection() which includes serviceID (needed for removes)
	var $w : Integer:=Current form window
	var $lines : Collection:=This._linesAsCollection()
	var $total : Real:=0
	var $tl : Object
	For each ($tl; $lines)
		$total:=$total+($tl.quantity*$tl.unitPrice)
	End for each 
	var $context : Object:={\
		windowID: $w; \
		eventID: This.event.ID; \
		eventDate: String(This.event.eventDate; "yyyy-MM-dd"); \
		guestCount: This.event.guestCount; \
		venueName: This.event.venue.name; \
		currentTotal: $total; \
		existingLines: $lines\
		}
	
	var $hiddenPrompt : Text:=$promptOverride || String($action.hiddenPrompt)
	// Store in session singleton — shared with worker process, no JSON round-trip
	cs.AIWorkerContext.me.storeAction($w; $action)
	cs.AIWorkerContext.me.storeExistingLines($w; $lines)
	var $ctxJson : Text:=JSON Stringify($context)
	CALL WORKER("aiAdvisorWorker_"+String($w); Formula(_aiExecuteWorkerJob($w; $hiddenPrompt; $ctxJson)))
	
// ─── switch_venue: build a smart prompt then route through normal tool-calling ───
Function _executeSwitchVenue($action : Object)
	var $evt : cs.EventEntity:=This.event
	var $venue : cs.VenueEntity:=$evt.venue
	
	var $indoorName : Text:="indoor option"
	var $indoorRental : Real:=0
	If (($venue#Null) && ($venue.indoorOption#Null))
		$indoorName:=String($venue.indoorOption.name)
		$indoorRental:=Num($venue.indoorOption.rentalPrice)
	End if 
	var $guestCount : Integer:=$evt.guestCount
	
	// List all booked services — let AI decide which are outdoor-specific
	var $allServices : Text:=""
	var $line : Object
	For each ($line; This.eventLines)
		$allServices:=$allServices+"- "+$line.serviceLabel+" x"+String($line.quantity)+" @ "+String($line.unitPrice)+"€\n"
	End for each 
	
	// Compute current services total — passed to system prompt for revenue protection
	var $currentTotal : Real:=0
	For each ($line; This.eventLines)
		$currentTotal:=$currentTotal+($line.quantity*$line.unitPrice)
	End for each 
	
	// Let AI identify outdoor-specific services and find indoor replacements
	var $prompt : Text:="This outdoor event is being switched to the indoor venue option '"+$indoorName+"' (rental: "+String($indoorRental)+"€).\n\n"
	$prompt:=$prompt+"Current booked services (total: "+String($currentTotal)+"€):\n"+$allServices+"\n"
	$prompt:=$prompt+"Task:\n"
	$prompt:=$prompt+"1. REMOVE all services that are specific to outdoor events (tents, outdoor structures, outdoor sound, outdoor lighting, rain gear, patio heaters, outdoor venue rental, etc.) — use your knowledge to identify them.\n"
	$prompt:=$prompt+"2. SEARCH for indoor equivalents and additions: indoor sound system for "+String($guestCount)+" guests, indoor lighting/decor upgrades, indoor comfort services. Do NOT search for venue rental — that is handled separately.\n"
	
	// Tag the action so confirm step knows to save venueOption + inject indoor rental
	$action._switchVenue:=True
	$action._indoorRental:=$indoorRental
	$action._indoorName:=$indoorName
	
	OBJECT SET TITLE(*; "text_ai_status"; "⏳ Switching to indoor — calculating replacements...")
	This._executeWithToolCalling($action; $prompt)
	
Function _onExecutionDone($execResult : Object)
	If (Form=Null)
		return 
	End if 
	
	// Retrieve and clear the stored action — no JSON round-trip needed
	var $action : Object:=cs.AIWorkerContext.me.getAction(Current form window)
	cs.AIWorkerContext.me.clearAction(Current form window)
	
	If (Not($execResult.success))
		OBJECT SET TITLE(*; "text_ai_status"; "❌ "+String($execResult.error))
		return 
	End if 
	
	If (($execResult.proposedLines=Null) || ($execResult.proposedLines.length=0))
		OBJECT SET TITLE(*; "text_ai_status"; "No services proposed.")
		return 
	End if 
	
	// For switch_venue: inject the indoor venue rental as a guaranteed add line
	// (AI may fail to find it; we always inject it from the venue's indoorOption.rentalPrice)
	If ($action._switchVenue=True) && (Num($action._indoorRental)>0)
		var $alreadyHasIndoor : Boolean:=$execResult.proposedLines.some(Formula(\
			($1.delta="add") && (Position("indoor"; Lowercase($1.label))>0) && (Position("rental"; Lowercase($1.label))>0)\
			))
		If (Not($alreadyHasIndoor))
			// Look up the real service so we use its actual ID
			var $indoorSvc : cs.ServiceEntity:=ds.Service.query("label = :1"; "Indoor venue rental").first()
			If ($indoorSvc#Null)
				$execResult.proposedLines.push({\
					delta: "add"; \
					serviceID: $indoorSvc.ID; \
					label: "Indoor venue rental"; \
					quantity: 1; \
					unitPrice: Num($action._indoorRental)\
					})
			End if 
		End if 
	End if 
	
	OBJECT SET TITLE(*; "text_ai_status"; "✓ Impact calculated")
	This._showValidationBadge("schema_action_execution.json"; $execResult.rawAiResponse)
	This._showConfirmPanel($action; $execResult)
	
Function _showConfirmPanel($action : Object; $execResult : Object)
	This._pendingAction:=$action
	This._pendingExecResult:=$execResult
	
	// Build confirmLines collection for the listbox
	var $lines : Collection:=[]
	var $totalImpact : Real:=0
	var $line : Object
	For each ($line; $execResult.proposedLines)
		var $lineTotal : Real:=$line.quantity*$line.unitPrice
		var $icon : Text
		var $impact : Real
		Case of 
			: ($line.delta="add")
				$icon:="➕"
				$impact:=$lineTotal
			: ($line.delta="remove")
				$icon:="🗑"
				$impact:=-$lineTotal
			: ($line.delta="update")
				$icon:="✏️"
				// Impact = (newQty - oldQty) * unitPrice; look up old qty from eventLines
				var $oldLine : cs.EventLineEntity:=This.eventLines.query("serviceID = :1"; $line.serviceID).first()
				var $oldQty : Integer:=$oldLine ? $oldLine.quantity : 0
				$impact:=($line.quantity-$oldQty)*$line.unitPrice
			Else 
				$icon:="·"
				$impact:=0
		End case 
		$totalImpact:=$totalImpact+$impact
		var $costStr : Text
		If ($impact>0)
			$costStr:="+"+String($impact; "### ### ##0")+" €"
		Else 
			If ($impact<0)
				$costStr:="−"+String(-$impact; "### ### ##0")+" €"
			Else 
				$costStr:="—"
			End if 
		End if 
		$lines.push({\
			deltaIcon: $icon; \
			label: $line.label; \
			qtyStr: "×"+String($line.quantity); \
			costImpactStr: $costStr\
			})
	End for each 
	This.confirmLines:=$lines
	
	// Compute new total from current eventLines + impact + venue rental
	var $currentTotal : Real:=0
	var $tl : cs.EventLineEntity
	For each ($tl; This.eventLines)
		$currentTotal:=$currentTotal+$tl.lineTotal
	End for each 
	// Include venue rental cost (same as displayed in event total)
	var $rentalPrice : Real:=This.event.venueRentalPrice
	If ($rentalPrice>0)
		$currentTotal:=$currentTotal+$rentalPrice
	End if 
	var $newTotal : Real:=$currentTotal+$totalImpact
	
	var $impactStr : Text
	If ($totalImpact>0)
		$impactStr:="+"+String($totalImpact; "### ### ##0")+" €"
	Else 
		If ($totalImpact<0)
			$impactStr:="−"+String(-$totalImpact; "### ### ##0")+" €"
		Else 
			$impactStr:="0 €"
		End if 
	End if 
	
	OBJECT SET TITLE(*; "text_confirm_title"; String($action.label))
	OBJECT SET TITLE(*; "text_confirm_summary"; String($execResult.summary))
	OBJECT SET TITLE(*; "text_confirm_impact_val"; $impactStr)
	OBJECT SET TITLE(*; "text_confirm_newtotal_val"; String($newTotal; "### ### ##0")+" €")
	This.confirmEmailDraft:=""
	This._setConfirmPanelVisible(True)
	This._resizeWindow(1460)
	
Function _hideConfirmPanel()
	This._setConfirmPanelVisible(False)
	This._resizeWindow(1100)
	This._pendingExecResult:=Null
	This._pendingAction:=Null
	
	// Called when all actions have been applied (directly or after reassessment).
	// Dismisses the weather alert or marks the pending email as processed,
	// then re-renders the AI panel to reflect the resolved state.
Function _dismissAfterActions()
	cs.UIHelpers.me.resetActionButtons()
	This.aiActions:=[]
	If (This.activeAdvisorTab="email")
		// Mark linked email as read so it disappears from the email queue
		If (This.linkedEmail#Null)
			This.linkedEmail.emailStatus:="processed"
			This.linkedEmail.save()
		End if 
		This.linkedEmail:=Null
		This.hasEmail:=False
	Else 
		// Update weatherSetup to match current forecast so no future alert is raised,
		// then clear the alert level
		var $forecast : Object:=This.event.weatherForecast
		If ($forecast#Null)
			This.event.weatherSetup:=$forecast
		End if 
		This.event.weatherAlertLevel:="none"
		This.event.save()
	End if 
	This._renderCurrentTab()
	// Refresh the event list counts/icons if available
	If (This._listFC#Null)
		CALL FORM(This._listFC._windowRef; Formula(Form._loadEvents(Form.activeFilter)))
	End if 
	
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
	OBJECT SET VISIBLE(*; "listbox_confirm_lines"; $visible)
	OBJECT SET VISIBLE(*; "text_confirm_impact_lbl"; $visible)
	OBJECT SET VISIBLE(*; "text_confirm_impact_val"; $visible)
	OBJECT SET VISIBLE(*; "text_confirm_newtotal_lbl"; $visible)
	OBJECT SET VISIBLE(*; "text_confirm_newtotal_val"; $visible)
	OBJECT SET VISIBLE(*; "rect_confirm_email_sep"; $visible)
	OBJECT SET VISIBLE(*; "text_confirm_email_lbl"; $visible)
	OBJECT SET VISIBLE(*; "input_confirm_email_draft"; $visible)
	OBJECT SET VISIBLE(*; "btn_draft_email"; $visible)
	OBJECT SET VISIBLE(*; "rect_confirm_footer_sep"; $visible)
	OBJECT SET VISIBLE(*; "btn_cancel_confirm"; $visible)
	OBJECT SET VISIBLE(*; "btn_confirm_action"; $visible)
	
Function btnConfirmActionEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			If (This._pendingExecResult=Null)
				return 
			End if 
			var $appliedAction : Object:=This._pendingAction
			
			// If this is a switch_venue action, update venueOption and rental price on the event
			If (($appliedAction.actionType="switch_venue") || ($appliedAction._switchVenue=True))
				var $evt : cs.EventEntity:=This.event
				$evt.venueOption:="indoor"
				var $venue : cs.VenueEntity:=$evt.venue
				If (($venue#Null) && ($venue.indoorOption#Null))
					$evt.venueRentalPrice:=Num($venue.indoorOption.rentalPrice)
				End if 
				$evt.save()
			End if 
			
			cs.EventLineService.me.applyProposedChanges(This.event.ID; This._pendingExecResult.proposedLines)
			var $appliedLabel : Text:=String($appliedAction.label)
			This._hideConfirmPanel()
			This._loadEventLines()
			
			// Remove the confirmed action from the list
			var $remaining : Collection:=This.aiActions.query("label != :1"; $appliedLabel)
			This.aiActions:=$remaining
			
			If ($remaining.length=0)
				This._dismissAfterActions()
			Else 
				// Reassess remaining actions with AI
				This._startSpinner()
				OBJECT SET TITLE(*; "text_ai_status"; "✅ Applied. Reassessing remaining actions...")
				var $w : Integer:=Current form window
				var $lbl : Text:=$appliedLabel
				var $remJson : Text:=JSON Stringify($remaining)
				var $linesJson : Text:=JSON Stringify(This._linesAsCollection())
				CALL WORKER("aiAdvisorWorker_"+String($w); Formula(_aiReassessWorkerJob($w; $remJson; $lbl; $linesJson)))
			End if 
	End case 
	
Function _onReassessmentDone($result : Object)
	If (Form=Null)
		return 
	End if 
	This._stopSpinner()
	cs.UIHelpers.me.resetActionButtons()
	If (Not($result.success))
		This._actionMap:=cs.UIHelpers.me.showActionButtons(This.aiActions)
		OBJECT SET TITLE(*; "text_ai_status"; "✅ Applied. (Reassessment failed: "+$result.validationError+")")
		return 
	End if 
	This.aiActions:=$result.actions
	If ($result.actions.length=0)
		This._dismissAfterActions()
	Else 
		This._actionMap:=cs.UIHelpers.me.showActionButtons($result.actions)
		OBJECT SET TITLE(*; "text_ai_status"; "✅ Applied. "+String($result.actions.length)+" action(s) remaining.")
		This._showValidationBadge("schema_reassess_actions.json"; $result.rawAiResponse)
	End if 
	
Function btnCancelConfirmEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._hideConfirmPanel()
			OBJECT SET TITLE(*; "text_ai_status"; "Action cancelled.")
	End case 
	
Function btnDraftEmailEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			If (This._pendingExecResult=Null)
				This.confirmEmailDraft:="(No proposed changes to draft an email for.)"
				return 
			End if 
			OBJECT SET TITLE(*; "text_ai_status"; "✉ Drafting confirmation email...")
			var $self : Object:=This
			var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
			var $evt : cs.EventEntity:=This.event
			var $act : Object:=This._pendingAction
			var $plines : Collection:=This._pendingExecResult.proposedLines
			$advisor.generateDraftEmailAsync($evt; $act; $plines; Formula($self._onDraftEmailDone($1)))
	End case 
	
Function _onDraftEmailDone($result : Object)
	If (Form=Null)
		return 
	End if 
	If (Not($result.success))
		OBJECT SET TITLE(*; "text_ai_status"; "❌ Email draft failed: "+$result.validationError)
		This.confirmEmailDraft:="(Email generation failed.)"
		return 
	End if 
	This.confirmEmailDraft:=$result.emailText
	OBJECT SET TITLE(*; "text_ai_status"; "✉ Draft email ready")
	This._showValidationBadge("schema_draft_email.json"; $result.rawAiResponse)
	
	//MARK: - Helpers
Function _startSpinner()
	This._spinnerActive:=True
	This._spinnerIndex:=0
	OBJECT SET TITLE(*; "text_ai_spinner"; This._spinnerFrames[0])
	OBJECT SET VISIBLE(*; "text_ai_spinner"; True)
	// Hide action buttons during spinner
	cs.UIHelpers.me.resetActionButtons()
	SET TIMER(6)  // ~100ms per frame
	
Function _stopSpinner()
	This._spinnerActive:=False
	SET TIMER(0)
	OBJECT SET VISIBLE(*; "text_ai_spinner"; False)
	OBJECT SET TITLE(*; "text_ai_spinner"; "")
Function _navigate($direction : Integer)
	var $pos : Integer:=This.event.indexOf(This._selection)
	If ($pos<0)
		return 
	End if 
	var $newPos : Integer:=$pos+$direction
	If (($newPos<0) || ($newPos>=This._selection.length))
		return 
	End if 
	var $newEvent : cs.EventEntity:=This._selection[$newPos]
	This.event:=$newEvent
	If (This._pendingExecResult#Null)
		This._hideConfirmPanel()
	End if 
	This._loadEventLines()
	This._checkLinkedEmail()
	This._renderCurrentTab()
	This._updateNavButtons()
	This._applyReadOnlyIfDone()
	// Sync selection in events list via CALL FORM
	If ((This._listFC#Null) && (This._listFC._windowRef>0))
		CALL FORM(This._listFC._windowRef; Formula(Form.currentEvent:=$1); This.event)
	End if 
	
Function _updateNavButtons()
	var $pos : Integer:=This.event.indexOf(This._selection)
	If ($pos<0)
		OBJECT SET ENABLED(*; "btn_prev"; False)
		OBJECT SET ENABLED(*; "btn_next"; False)
	Else 
		OBJECT SET ENABLED(*; "btn_prev"; $pos>0)
		OBJECT SET ENABLED(*; "btn_next"; $pos<(This._selection.length-1))
	End if 
	
Function _linesAsCollection() : Collection
	var $col : Collection:=[]
	var $line : cs.EventLineEntity
	For each ($line; This.eventLines)
		$col.push({\
			serviceID: $line.serviceID; \
			serviceLabel: $line.serviceLabel; \
			category: $line.serviceCategory; \
			quantity: $line.quantity; \
			unitPrice: $line.unitPrice\
			})
	End for each 
	return $col
	
Function _applyReadOnlyIfDone()
	var $isDone : Boolean:=((This.event.status="completed") || (This.event.status="cancelled"))
	OBJECT SET ENABLED(*; "btn_ai_analyze"; Not($isDone))
	OBJECT SET ENABLED(*; "btn_ai_action1"; Not($isDone))
	OBJECT SET ENABLED(*; "btn_ai_action2"; Not($isDone))
	OBJECT SET ENABLED(*; "btn_ai_action3"; Not($isDone))
	OBJECT SET ENABLED(*; "btn_ai_action4"; Not($isDone))
	If ($isDone)
		OBJECT SET TITLE(*; "text_ai_status"; "This event is "+This.event.status+" and cannot be modified.")
	End if 
	