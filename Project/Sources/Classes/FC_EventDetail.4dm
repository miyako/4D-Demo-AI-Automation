// FC_EventDetail.4dm
// Scenario 2: Weather alert + AI panel with contextual actions

property event : cs.EventEntity
property aiActions : Collection
property confirmDraft : Text
property confirmEmailDraft : Text
property confirmLines : Collection
property running : Boolean
property _spinnerIndex : Integer
property _spinnerFrames : Collection
property _spinnerActive : Boolean
property _spinnerBtnSlot : Integer
property _spinnerBtnLabel : Text
property _spinnerAnalyzeBtn : Text
property _spinnerAnalyzeLabel : Text
property _aiStatusBase : Text
property _selection : cs.EventSelection
property _pendingExecResult : Object
property _pendingAction : Object
property activeAdvisorTab : Text
property tabControl : Object
property _lastValidationData : Object
property _actionMap : Collection
property _weatherExplanation : Text
property _listFC : Object

Class constructor($event : cs.EventEntity; $eventSelection : cs.EventSelection; $listFC : Object)
	This.event:=$event
	This.aiActions:=[]
	This.confirmDraft:=""
	This.confirmEmailDraft:=""
	This.confirmLines:=[]
	This.running:=False
	This._spinnerIndex:=0
	This._spinnerFrames:=cs.UIHelpers.me.spinnerFrames()
	This._spinnerActive:=False
	This._spinnerBtnSlot:=-1
	This._spinnerBtnLabel:=""
	This._spinnerAnalyzeBtn:=""
	This._spinnerAnalyzeLabel:=""
	This._aiStatusBase:=""
	This._pendingExecResult:=Null
	This._pendingAction:=Null
	This.activeAdvisorTab:="weather"
	//This.tabControl:=New object("values"; New collection("⛅ Weather"; "📧 Email"); "index"; 0)
	This.tabControl:=New object("values"; New collection("⛅ 天候"; "📧 メール"); "index"; 0)
	This._lastValidationData:=Null
	This._actionMap:=[-1; -1; -1; -1]
	This._weatherExplanation:=""
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
			If (This._spinnerActive || (This._spinnerBtnSlot>=0) || (This._spinnerAnalyzeBtn#""))
				This._spinnerIndex:=(This._spinnerIndex+1)%(This._spinnerFrames.length)
				var $frame : Text:=This._spinnerFrames[This._spinnerIndex]
				If (This._spinnerActive)
					OBJECT SET TITLE(*; "text_ai_status"; $frame+" "+This._aiStatusBase)
				End if 
				If (This._spinnerBtnSlot>=0)
					var $btns : Collection:=["btn_ai_action1"; "btn_ai_action2"; "btn_ai_action3"; "btn_ai_action4"]
					OBJECT SET TITLE(*; $btns[This._spinnerBtnSlot]; This._spinnerBtnLabel+"  "+$frame)
				End if 
				If (This._spinnerAnalyzeBtn#"")
					OBJECT SET TITLE(*; This._spinnerAnalyzeBtn; This._spinnerAnalyzeLabel+"  "+$frame)
				End if 
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
	cs.UIHelpers.me.resizeWindowWidth(1100)
	This._loadEventLines()
	This._renderCurrentTab()
	This._updateNavButtons()
	This._applyReadOnlyIfDone()
	
Function _loadEventLines()
	This.event.reload()  // ensure relation cache is fresh
	
	// Compute total from all event lines (venue rental is already an EventLine)
	var $total : Real:=0
	var $line : cs.EventLineEntity
	For each ($line; This.event.lines)
		$total:=$total+$line.lineTotal
	End for each 
	OBJECT SET TITLE(*; "text_total_val"; String($total; "### ### ##0 €"))
	
Function _clearAIPanel()
	cs.UIHelpers.me.resetActionButtons()
	This.aiActions:=[]
	This._lastValidationData:=Null
	OBJECT SET TITLE(*; "text_ai_context"; "")
	This._setAiStatus("")
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
		//$setupStr:="Planned: "+This.event.setupLabel
		$setupStr:="想定: "+This.event.setupLabel
	End if 
	If ($forecast#Null)
		//$setupStr:=$setupStr+"\nForecast: "+This.event.forecastLabel
		$setupStr:=$setupStr+"\n予報: "+This.event.forecastLabel
	End if 
	OBJECT SET TITLE(*; "text_ai_context"; $setupStr)
	
	If ($weatherResult=Null)
		var $level : Text:=This.event.weatherAlertLevel
		var $hasAlert : Boolean:=(($level#"none") && ($level#""))
		If ($hasAlert)
			//This._setAiStatus("⚠ Weather alert: "+$level)
			
			Case of 
				: ($level="critical")
					$level:="危険"
				: ($level="warning")
					$level:="警告"
				: ($level="watch")
					$level:="警戒"
			End case 
			
			This._setAiStatus("⚠️ 天候アラート: "+$level)
			OBJECT SET VISIBLE(*; "btn_ai_analyze"; True)
		Else 
			//This._setAiStatus("No weather alerts detected.")
			This._setAiStatus("天候アラート: なし")
			OBJECT SET VISIBLE(*; "btn_ai_analyze"; False)
		End if 
		return 
	End if 
	
	If (Not($weatherResult.success))
		//This._setAiStatus("⚠ Analysis failed: "+$weatherResult.validationError)
		This._setAiStatus("⚠ 分析に失敗しました: "+$weatherResult.validationError)
		
		return 
	End if 
	
	This._setAiStatus(This.event.riskLabel)
	
	If ($weatherResult.summary#"")
		OBJECT SET TITLE(*; "text_weather_ai_explanation"; $weatherResult.summary)
		This._weatherExplanation:=$weatherResult.summary
	End if 
	
	This._showValidationBadge("schema_weather_actions.json"; $weatherResult.rawAiResponse)
	
	This._actionMap:=cs.UIHelpers.me.showActionButtons($weatherResult.actions)
	This.aiActions:=$weatherResult.actions
	
Function _renderEmailTab()
	var $e : cs.EmailEntity:=This.event.pendingEmail
	var $hasEmail : Boolean:=(Not(Undefined($e)) && ($e#Null))
	OBJECT SET VISIBLE(*; "text_email_ai_result"; True)
	OBJECT SET VISIBLE(*; "input_email_body"; $hasEmail)
	OBJECT SET VISIBLE(*; "btn_email_analyze"; $hasEmail)
	If ($hasEmail)
		var $meta : Text:="Subject: "+$e.subject+"\nFrom: "+$e.sender+" <"+$e.senderEmail+">\nReceived: "+String($e.receivedAt; "dd MMM yyyy")
		OBJECT SET TITLE(*; "text_ai_context"; $meta)
		OBJECT SET VALUE("input_email_body"; $e.body)
		OBJECT SET TITLE(*; "text_email_ai_result"; "")
		//This._setAiStatus("📧 Email pending")
		This._setAiStatus("📧 未処理のメールがあります")
	Else 
		//OBJECT SET TITLE(*; "text_ai_context"; "No pending email for this event.")
		OBJECT SET TITLE(*; "text_ai_context"; "イベントに関する未処理のメールはありません")
		//This._setAiStatus("No email to process.")
		This._setAiStatus("未処理のメールはありません")
	End if 
	
Function _checkAiReady() : Boolean
	return cs.UIHelpers.me.checkAliasOrPrompt("chat-reasoning") && cs.UIHelpers.me.checkAliasOrPrompt("chat-simple")
	
Function _runWeatherAnalysis()
	If (Not(This._checkAiReady()))
		return 
	End if 
	This._logUserAction("Weather Analysis"; "User pressed Weather Analysis button")
	This.running:=True
	This._startSpinner()
	//This._startAnalyzeSpinner("btn_ai_analyze"; "⚡ Run AI Weather Analysis")
	This._startAnalyzeSpinner("btn_ai_analyze"; "⚡ AI天気予報アナライザーを起動")
	If (This._pendingExecResult#Null)
		This._hideConfirmPanel()
	End if 
	//This._setAiStatus("Fetching weather data...")
	This._setAiStatus("天候データを取得中...")
	
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
	
	//This._setAiStatus("Asking AI for recommendations...")
	This._setAiStatus("AIに対策を相談中...")
	
	var $w : Integer:=Current form window
	var $evtID : Text:=This.event.ID
	cs.AIWorkerContext.me.storeContractRef($w; This.event.contractRef)
	CALL WORKER("aiAdvisorWorker_"+String($w); Formula(_aiWeatherWorkerJob($w; $evtID)))
	
	// ─── Callbacks async ─────────────────────────────────────────────────────────
Function _onWeatherAnalysisDone($aiResult : Object)
	If (Form=Null)
		return 
	End if 
	This.running:=False
	This._stopSpinner()
	This._stopAnalyzeSpinner()
	This._clearAIPanel()
	OBJECT SET VISIBLE(*; "text_weather_ai_explanation"; True)
	This._renderWeatherTab($aiResult)
	
	// ─── Tab management ───────────────────────────────────────────────────────────
Function _setAdvisorTab($tab : Text)
	This.activeAdvisorTab:=$tab
	This._hideConfirmPanel()
	This._renderCurrentTab()
	
	// ─── Email AI analysis ────────────────────────────────────────────────────────
Function btnEmailAnalyzeEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._runEmailAnalysis()
	End case 
	
Function _runEmailAnalysis()
	If (Not(This._checkAiReady()))
		return 
	End if 
	var $pendingEmail : cs.EmailEntity:=This.event.pendingEmail
	If (Undefined($pendingEmail) || ($pendingEmail=Null))
		return 
	End if 
	This._logUserAction("Email Analysis"; "User pressed Analyze Email subject: "+String($pendingEmail.subject))
	This.running:=True
	This._startSpinner()
	//This._startAnalyzeSpinner("btn_email_analyze"; "📧 Analyze Email with AI")
	This._startAnalyzeSpinner("btn_email_analyze"; "📧 AIメールアナライザーを起動")
	
	If (This._pendingExecResult#Null)
		This._hideConfirmPanel()
	End if 
	//This._setAiStatus("Analyzing modification request...")
	This._setAiStatus("AIに対策を相談中...")
	var $evt : cs.EventEntity:=This.event
	var $w : Integer:=Current form window
	var $emailID : Text:=$pendingEmail.ID
	var $eventID : Text:=String($evt.ID)
	cs.AIWorkerContext.me.storeContractRef($w; $evt.contractRef)
	CALL WORKER("aiAdvisorWorker_"+String($w); Formula(_aiEmailWorkerJob($w; $emailID; $eventID)))
	
Function _onEmailAnalysisDone($result : Object)
	If (Form=Null)
		return 
	End if 
	This.running:=False
	This._stopSpinner()
	This._stopAnalyzeSpinner()
	
	If (Not($result.success))
		//This._setAiStatus("❌ Email analysis failed")
		This._setAiStatus("❌ メールの分析に失敗しました")
		OBJECT SET TITLE(*; "text_email_ai_result"; $result.validationError ? $result.validationError : "Analysis failed")
		return 
	End if 
	
	//This._setAiStatus("✓ Modification request analyzed")
	This._setAiStatus("✓ AIの提案を分析しました")
	
	This._showValidationBadge("schema_modification_impacts.json"; $result.rawAiResponse)
	
	OBJECT SET TITLE(*; "text_email_ai_result"; $result.summary)
	
	If (($result.actions#Null) && ($result.actions.length>0))
		This._actionMap:=cs.UIHelpers.me.showActionButtons($result.actions)
		This.aiActions:=$result.actions
		// Hide analyze button once actions are proposed user cannot re-trigger analysis
		OBJECT SET VISIBLE(*; "btn_email_analyze"; False)
	Else 
		//This._setAiStatus("✓ No service changes required")
		This._setAiStatus("✓ サービスの見直しは必要ありません")
	End if 
	
Function _executeAction($slot : Integer)
	var $actionIdx : Integer:=This._actionMap[$slot]
	If (($actionIdx<0) || ($actionIdx>=This.aiActions.length))
		return 
	End if 
	var $action : Object:=This.aiActions[$actionIdx]
	var $type : Text:=$action.actionType
	This._logUserAction("Action Pressed"; String($action.label)+" ["+$type+"]")
	This._hideConfirmPanel()
	
	// switch_venue: update venueOption and rental price directly no AI tool call needed
	If ($type="switch_venue")
		This._startButtonSpinner($slot; $action.label)
		This._executeSwitchVenue($action)
		return 
	End if 
	
	// If the action has a hiddenPrompt, use tool calling (Step 2)
	If (($action.hiddenPrompt#Null) && ($action.hiddenPrompt#""))
		This._startButtonSpinner($slot; $action.label)
		This._setAiStatus(""+String($action.label)+"...")
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
	// $promptOverride: optional if provided, replaces the action's hiddenPrompt
Function _executeWithToolCalling($action : Object; $promptOverride : Text)
	This._startSpinner()
	//This._setAiStatus("Searching services...")
	This._setAiStatus("サービスを検索中...")
	
	// Event context filter out Venue-category services (venue rental handled server-side)
	var $w : Integer:=Current form window
	var $lines : Collection:=This._linesAsCollection().query("serviceCategory != :1"; "Venue")
	var $context : Object:={\
		windowID: $w; \
		contractRef: This.event.contractRef; \
		eventDate: String(This.event.eventDate; "yyyy-MM-dd"); \
		guestCount: This.event.guestCount; \
		venueName: This.event.venue.name; \
		existingLines: $lines\
		}
	
	var $hiddenPrompt : Text:=$promptOverride || String($action.hiddenPrompt)
	// Store in session singleton shared with worker process, no JSON round-trip
	cs.AIWorkerContext.me.storeAction($w; $action)
	cs.AIWorkerContext.me.storeExistingLines($w; $lines)
	cs.AIWorkerContext.me.storeContractRef($w; This.event.contractRef)
	var $ctxJson : Text:=JSON Stringify($context)
	CALL WORKER("aiAdvisorWorker_"+String($w); Formula(_aiExecuteWorkerJob($w; $hiddenPrompt; $ctxJson)))
	
	// ─── switch_venue: bidirectional, compute venue balance, single-round prompt ───
Function _executeSwitchVenue($action : Object)
	var $evt : cs.EventEntity:=This.event
	var $venue : cs.VenueEntity:=$evt.venue
	var $isToIndoor : Boolean:=($evt.venueOption="outdoor")
	
	var $oldRentalPrice : Real:=Num($evt.venueRentalPrice)
	var $newRentalPrice : Real:=0
	var $newVenueName : Text:=""
	If ($isToIndoor)
		$newRentalPrice:=($venue#Null) && ($venue.indoorOption#Null) ? Num($venue.indoorOption.rentalPrice) : 0
		$newVenueName:=($venue#Null) && ($venue.indoorOption#Null) ? String($venue.indoorOption.name) : "indoor option"
	Else 
		$newRentalPrice:=($venue#Null) && ($venue.outdoorOption#Null) ? Num($venue.outdoorOption.rentalPrice) : 0
		$newVenueName:=($venue#Null) && ($venue.outdoorOption#Null) ? String($venue.outdoorOption.name) : "outdoor option"
	End if 
	
	$action._switchVenue:=True
	$action._isToIndoor:=$isToIndoor
	$action._oldRentalPrice:=$oldRentalPrice
	$action._newRentalPrice:=$newRentalPrice
	$action._newVenueName:=$newVenueName
	$action._venueBalance:=$newRentalPrice-$oldRentalPrice
	
	var $prompt : Text:=cs.AIAdvisor.new().switchVenuePrompt($isToIndoor; $newVenueName; $action._venueBalance; $evt.guestCount)
	//This._setAiStatus("Switching venue calculating changes...")
	This._setAiStatus("開催地の変更に伴う費用を計算中...")
	This._executeWithToolCalling($action; $prompt)
	
Function _onExecutionDone($execResult : Object)
	If (Form=Null)
		return 
	End if 
	
	This._stopButtonSpinner()
	This._stopSpinner()
	
	// Retrieve and clear the stored action no JSON round-trip needed
	var $action : Object:=cs.AIWorkerContext.me.getAction(Current form window)
	cs.AIWorkerContext.me.clearAction(Current form window)
	
	If (Not($execResult.success))
		This._setAiStatus("❌ "+String($execResult.error))
		return 
	End if 
	
	If (($execResult.proposedLines=Null) || ($execResult.proposedLines.length=0))
		//var $noSvcMsg : Text:="No services proposed."
		var $noSvcMsg : Text:="サービスの見直しは必要ないと思われます。"
		If ($execResult.summary#"")
			$noSvcMsg:=$noSvcMsg+" (AI: "+$execResult.summary+")"
		End if 
		This._setAiStatus($noSvcMsg)
		return 
	End if 
	
	// For switch_venue: server-side venue rental swap
	If ($action._switchVenue=True)
		// Venue rental swap handled below no server-side budget cap, AI manages the target
		
		// Inject server-side venue rental: remove old, add new
		var $oldVenueLine : cs.EventLineEntity:=This.event.lines.query("serviceCategory = :1"; "Venue").first()
		If ($oldVenueLine#Null)
			$execResult.proposedLines.unshift({\
				delta: "remove"; \
				serviceID: $oldVenueLine.serviceID; \
				label: $oldVenueLine.serviceLabel; \
				quantity: $oldVenueLine.quantity; \
				unitPrice: $oldVenueLine.unitPrice\
				})
		End if 
		var $newRentalPrice : Real:=Num($action._newRentalPrice)
		If ($newRentalPrice>0)
			var $newVenueLabel : Text:=$action._isToIndoor ? "Indoor venue rental" : "Outdoor venue rental"
			var $newVenueSvc : cs.ServiceEntity:=ds.Service.query("label = :1"; $newVenueLabel).first()
			If ($newVenueSvc#Null)
				$execResult.proposedLines.push({\
					delta: "add"; \
					serviceID: $newVenueSvc.ID; \
					label: $newVenueLabel; \
					quantity: 1; \
					unitPrice: $newRentalPrice\
					})
			End if 
		End if 
	End if 
	
	//This._setAiStatus("✓ Impact calculated")
	This._setAiStatus("✓ コスト計算が完了しました")
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
				var $oldLine : cs.EventLineEntity:=This.event.lines.query("serviceID = :1"; $line.serviceID).first()
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
				$costStr:=""
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
	
	// Compute new total from current event lines + impact (venue rental is already an EventLine)
	var $currentTotal : Real:=0
	var $tl : cs.EventLineEntity
	For each ($tl; This.event.lines)
		$currentTotal:=$currentTotal+$tl.lineTotal
	End for each 
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
	cs.UIHelpers.me.resizeWindowWidth(1460)
	
Function _hideConfirmPanel()
	This._setConfirmPanelVisible(False)
	cs.UIHelpers.me.resizeWindowWidth(1100)
	This._pendingExecResult:=Null
	This._pendingAction:=Null
	
	// Called when all actions have been applied (directly or after reassessment).
	// Dismisses the weather alert or marks the pending email as processed,
	// then re-renders the AI panel to reflect the resolved state.
Function _markAllPendingEmailsProcessed()
	var $pending : cs.EmailSelection:=ds.Email.query("emailStatus = :1 AND linkedEvent.ID = :2"; "pending"; This.event.ID)
	var $e : cs.EmailEntity
	For each ($e; $pending)
		$e.emailStatus:="processed"
		$e.save()
	End for each 
	
Function _dismissAfterActions()
	cs.UIHelpers.me.resetActionButtons()
	This.aiActions:=[]
	If (This.activeAdvisorTab#"email")
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
			This._logUserAction("Confirm Action"; String($appliedAction.label))
			// If this is a switch_venue action, update venueOption and rental price on the event
			If (($appliedAction.actionType="switch_venue") || ($appliedAction._switchVenue=True))
				var $evt : cs.EventEntity:=This.event
				If ($appliedAction._isToIndoor=True)
					$evt.venueOption:="indoor"
				Else 
					$evt.venueOption:="outdoor"
				End if 
				If ($appliedAction._newRentalPrice#Null)
					$evt.venueRentalPrice:=Num($appliedAction._newRentalPrice)
				End if 
				$evt.save()
			End if 
			
			// If action carries a new guest count, update the event
			If (($appliedAction.newGuestCount#Null) && (Num($appliedAction.newGuestCount)>0))
				This.event.guestCount:=Num($appliedAction.newGuestCount)
				This.event.save()
			End if 
			
			cs.EventLineService.me.applyProposedChanges(This.event.ID; This._pendingExecResult.proposedLines)
			var $appliedLabel : Text:=String($appliedAction.label)
			This._hideConfirmPanel()
			This._loadEventLines()
			
			// Remove the confirmed action from the list
			var $remaining : Collection:=This.aiActions.query("label != :1"; $appliedLabel)
			This.aiActions:=$remaining
			
			// If on email tab and no more actions, mark all pending emails as processed now
			If ((This.activeAdvisorTab="email") && ($remaining.length=0))
				This._markAllPendingEmailsProcessed()
			End if 
			
			If ($remaining.length=0)
				This._dismissAfterActions()
			Else 
				// Reassess remaining actions with AI
				This._startSpinner()
				//This._setAiStatus("✅ Applied. Reassessing remaining actions...")
				This._setAiStatus("✅ 変更を適用しました。必要な処理を算定中...")
				
				var $w : Integer:=Current form window
				var $lbl : Text:=$appliedLabel
				var $remJson : Text:=JSON Stringify($remaining)
				var $evtID : Text:=This.event.ID
				CALL WORKER("aiAdvisorWorker_"+String($w); Formula(_aiReassessWorkerJob($w; $remJson; $lbl; $evtID)))
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
		//This._setAiStatus("✅ Applied. (Reassessment failed: "+$result.validationError+")")
		This._setAiStatus("✅ 変更を適用しました。(必要な処理の算定に失敗しました: "+$result.validationError+")")
		return 
	End if 
	This.aiActions:=$result.actions
	If ($result.actions.length=0)
		// If on email tab, mark all pending emails as processed before dismiss
		If (This.activeAdvisorTab="email")
			This._markAllPendingEmailsProcessed()
		End if 
		This._dismissAfterActions()
	Else 
		This._actionMap:=cs.UIHelpers.me.showActionButtons($result.actions)
		//This._setAiStatus("✅ Applied. "+String($result.actions.length)+" action(s) remaining.")
		This._setAiStatus("✅ 変更を適用しました。"+String($result.actions.length)+"件の処理がさらに必要です。")
		This._showValidationBadge("schema_reassess_actions.json"; $result.rawAiResponse)
	End if 
	
Function btnCancelConfirmEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			var $cancelLabel : Text:=(This._pendingAction#Null) ? String(This._pendingAction.label) : ""
			This._logUserAction("Cancel Action"; $cancelLabel)
			This._hideConfirmPanel()
			//This._setAiStatus("Action cancelled.")
			This._setAiStatus("キャンセルしました")
	End case 
	
Function btnDraftEmailEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			If (This._pendingExecResult=Null)
				//This.confirmEmailDraft:="(No proposed changes to draft an email for.)"
				This.confirmEmailDraft:="(メールの必要な変更処理は提案されませんでした)"
				return 
			End if 
			This._logUserAction("Draft Email Requested"; String(This._pendingAction ? This._pendingAction.label : ""))
			//This._setAiStatus("✉ Drafting confirmation email...")
			This._setAiStatus("📧 確定メールの下書きを準備中...")
			var $self : Object:=This
			var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
			var $evt : cs.EventEntity:=This.event
			var $act : Object:=This._pendingAction
			var $plines : Collection:=This._pendingExecResult.proposedLines
			// Build context: weather explanation and/or client email depending on active tab
			var $ctx : Object:={}
			If ((This._weatherExplanation#Null) && (This._weatherExplanation#""))
				$ctx.weatherExplanation:=This._weatherExplanation
			End if 
			If (This.event.pendingEmail#Null)
				var $pe : cs.EmailEntity:=This.event.pendingEmail
				$ctx.clientEmail:={sender: $pe.sender; subject: $pe.subject; body: $pe.body}
			End if 
			$advisor.generateDraftEmailAsync($evt; $act; $plines; $ctx; Formula($self._onDraftEmailDone($1)))
	End case 
	
Function _onDraftEmailDone($result : Object)
	If (Form=Null)
		return 
	End if 
	If (Not($result.success))
		//This._setAiStatus("❌ Email draft failed: "+$result.validationError)
		This._setAiStatus("❌ メールの下書きが用意できませんでした: "+$result.validationError)
		This.confirmEmailDraft:="(Email generation failed.)"
		return 
	End if 
	This.confirmEmailDraft:=$result.emailText
	This._logUserAction("Draft Email"; $result.emailText)
	//This._setAiStatus("✉ Draft email ready")
	This._setAiStatus("📧 メールの下書きが用意できました")
	This._showValidationBadge("schema_draft_email.json"; $result.rawAiResponse)
	
	//MARK: - Helpers
Function _setAiStatus($text : Text)
	This._aiStatusBase:=$text
	If (This._spinnerActive)
		OBJECT SET TITLE(*; "text_ai_status"; This._spinnerFrames[This._spinnerIndex]+" "+$text)
	Else 
		OBJECT SET TITLE(*; "text_ai_status"; $text)
	End if 
	
Function _startSpinner()
	This._spinnerActive:=True
	This._spinnerIndex:=0
	OBJECT SET VISIBLE(*; "text_ai_spinner"; False)  // no longer used for main spinner
	If (This._spinnerBtnSlot<0)
		// Only reset buttons if no button spinner is running and no actions are pending
		If (This.aiActions.length=0)
			cs.UIHelpers.me.resetActionButtons()
		End if 
		SET TIMER(6)  // ~100ms per frame
	End if 
	
Function _startButtonSpinner($slot : Integer; $label : Text)
	This._spinnerBtnSlot:=$slot
	This._spinnerBtnLabel:=$label
	This._spinnerIndex:=0
	If (Not(This._spinnerActive))
		SET TIMER(6)
	End if 
	
Function _startAnalyzeSpinner($btnName : Text; $label : Text)
	This._spinnerAnalyzeBtn:=$btnName
	This._spinnerAnalyzeLabel:=$label
	If (Not(This._spinnerActive)) && (This._spinnerBtnSlot<0)
		SET TIMER(6)
	End if 
	
Function _stopButtonSpinner()
	If (This._spinnerBtnSlot>=0)
		var $btns : Collection:=["btn_ai_action1"; "btn_ai_action2"; "btn_ai_action3"; "btn_ai_action4"]
		OBJECT SET TITLE(*; $btns[This._spinnerBtnSlot]; This._spinnerBtnLabel)
		This._spinnerBtnSlot:=-1
		This._spinnerBtnLabel:=""
	End if 
	If (Not(This._spinnerActive)) && (This._spinnerAnalyzeBtn="")
		SET TIMER(0)
	End if 
	
Function _stopAnalyzeSpinner()
	If (This._spinnerAnalyzeBtn#"")
		OBJECT SET TITLE(*; This._spinnerAnalyzeBtn; This._spinnerAnalyzeLabel)
		This._spinnerAnalyzeBtn:=""
		This._spinnerAnalyzeLabel:=""
	End if 
	If (Not(This._spinnerActive)) && (This._spinnerBtnSlot<0)
		SET TIMER(0)
	End if 
	
Function _stopSpinner()
	This._spinnerActive:=False
	OBJECT SET TITLE(*; "text_ai_status"; This._aiStatusBase)
	If (This._spinnerBtnSlot<0) && (This._spinnerAnalyzeBtn="")
		SET TIMER(0)
	End if 
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
	return This.event.lines.toCollection("serviceID, serviceLabel, serviceCategory, quantity, unitPrice")
	
Function _applyReadOnlyIfDone()
	var $isDone : Boolean:=((This.event.status="completed") || (This.event.status="cancelled"))
	OBJECT SET ENABLED(*; "btn_ai_analyze"; Not($isDone))
	OBJECT SET ENABLED(*; "btn_ai_action1"; Not($isDone))
	OBJECT SET ENABLED(*; "btn_ai_action2"; Not($isDone))
	OBJECT SET ENABLED(*; "btn_ai_action3"; Not($isDone))
	OBJECT SET ENABLED(*; "btn_ai_action4"; Not($isDone))
	If ($isDone)
		//This._setAiStatus("This event is "+This.event.status+" and cannot be modified.")
		This._setAiStatus(This.event.status+"のイベントは変更できません")
	End if 
	
Function _logUserAction($tag : Text; $detail : Text)
	var $ref : Text:=String(This.event.contractRef)
	If ($ref#"")
		cs.EventLogger.me.logBlock($ref; "USER"; $tag; $detail)
	End if 
	