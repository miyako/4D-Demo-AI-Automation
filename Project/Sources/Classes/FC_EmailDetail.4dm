// FC_EmailDetail.4dm
// Scénario 1 (devis) et Scénario 3 (modification) — analyse IA + panneau d'actions

property email : cs.EmailEntity
property event : cs.EventEntity
property eventLines : Collection
property confirmLines : Collection
property aiActions : Collection
property aiResult : Object
property running : Boolean
property _catalog : Collection
property _pendingExecResult : Object
property _pendingAction : Object
property _pendingActionIndex : Integer

Class constructor($email : cs.EmailEntity)
	This.email:=$email
	This.event:=Null
	This.eventLines:=[]
	This.confirmLines:=[]
	This.aiActions:=[]
	This.aiResult:=Null
	This.running:=False
	This._catalog:=Null
	This._pendingExecResult:=Null
	This._pendingAction:=Null
	This._pendingActionIndex:=-1

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

Function btnAiAnalyzeEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._runAnalysis()
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

Function btnConfirmActionEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			If (This._pendingExecResult=Null)
				return 
			End if 
			var $confirmedIndex : Integer:=This._pendingActionIndex
			var $eventID : Text:=This._pendingExecResult.eventID
			cs.EventLineService.me.applyProposedChanges($eventID; This._pendingExecResult.proposedLines)
			This._hideConfirmPanel()
			This._loadEventLines()
			If (($confirmedIndex>=0) && ($confirmedIndex<This.aiActions.length))
				This.aiActions.remove($confirmedIndex; 1)
			End if 
			cs.UIHelpers.me.resetActionButtons()
			cs.UIHelpers.me.showActionButtons(This.aiActions)
			OBJECT SET TITLE(*; "text_ai_status"; "✅ Action applied.")
	End case 

Function btnCancelConfirmEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._hideConfirmPanel()
			OBJECT SET TITLE(*; "text_ai_status"; "Action cancelled.")
	End case 
Function _onLoad()
	var $m : cs.EmailEntity:=This.email
	OBJECT SET TITLE(*; "text_subject"; $m.subject)
	OBJECT SET TITLE(*; "text_from_val"; $m.sender)
	OBJECT SET TITLE(*; "text_email_val"; $m.senderEmail)
	OBJECT SET TITLE(*; "text_date_val"; String($m.receivedAt; "EEEE dd MMMM yyyy"))
	OBJECT SET TITLE(*; "text_type_badge"; cs.UIHelpers.me.typeBadgeFull($m.emailType))
	OBJECT SET TITLE(*; "text_ai_sub"; This._aiSubtitle($m.emailType))

	// Email body — input field, use OBJECT SET VALUE
	OBJECT SET VALUE("text_body"; $m.body)

	If ($m.linkedEventID#"")
		var $evt : cs.EventEntity:=ds.Event.get($m.linkedEventID)
		If ($evt#Null)
			OBJECT SET TITLE(*; "text_linked_event"; "Linked to: "+$evt.contractRef+" – "+$evt.venue.name+" – "+String($evt.eventDate; "dd/MM/yyyy"))
		End if 
	End if 

	This._setEventPanelVisible(False)
	This._setConfirmPanelVisible(False)
	This._resetAIPanel()

Function _runAnalysis()
	This.running:=True
	OBJECT SET TITLE(*; "btn_ai_analyze"; "⏳ Analyzing...")
	OBJECT SET TITLE(*; "text_ai_status"; "AI is reading the email...")
	This._resetActionButtons()

	var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
	var $emailType : Text:=This.email.emailType
	var $self : Object:=This

	Case of 
		: ($emailType="quote")
			OBJECT SET TITLE(*; "text_ai_status"; "Extracting quote information...")
			var $catalog : Collection:=This._getCatalog()
			$advisor.analyzeQuoteEmailAsync(This.email; $catalog; Formula($self._onQuoteAnalysisDone($1)))

		: ($emailType="modification")
			OBJECT SET TITLE(*; "text_ai_status"; "Identifying related events...")
			var $analyzer : cs.EmailAnalyzer:=cs.EmailAnalyzer.me
			var $candidates : Collection:=$analyzer.buildCandidateCollection(This.email)
			var $lines : Collection:=[]
			If ($candidates.length>0)
				$lines:=$analyzer.buildEventLinesCollection($candidates[0].eventID)
			End if 
			OBJECT SET TITLE(*; "text_ai_status"; "Analyzing modification impacts...")
			$advisor.analyzeModificationEmailAsync(This.email; $candidates; $lines; Formula($self._onModificationAnalysisDone($1)))

		Else 
			OBJECT SET TITLE(*; "text_ai_status"; "ℹ Info email – no action required.")
			This.running:=False
			OBJECT SET TITLE(*; "btn_ai_analyze"; "⚡ Analyze with AI")
	End case 

// ─── Callbacks async ─────────────────────────────────────────────────────────
Function _onQuoteAnalysisDone($result : Object)
	If (Form=Null)
		return 
	End if 
	This.aiResult:=$result
	This._renderQuoteResult($result)
	This.running:=False
	OBJECT SET TITLE(*; "btn_ai_analyze"; "⚡ Analyze with AI")

Function _onModificationAnalysisDone($result : Object)
	If (Form=Null)
		return 
	End if 
	This.aiResult:=$result
	// If event was identified (not ambiguous), load and show it
	If ($result.success && Not($result.ambiguous))
		var $data : Object:=$result.impacts
		If (($data.eventID#Null) && ($data.eventID#""))
			This.event:=ds.Event.get($data.eventID)
			This._loadEventLines()
			This._populateEventPanel()
			This._setEventPanelVisible(True)
		End if 
	End if 
	This._renderModificationResult($result)
	This.running:=False
	OBJECT SET TITLE(*; "btn_ai_analyze"; "⚡ Analyze with AI")

Function _renderQuoteResult($result : Object)
	If (Not($result.success))
		OBJECT SET TITLE(*; "text_ai_status"; "⚠ Analysis failed")
		OBJECT SET TITLE(*; "text_ai_context"; $result.validationError)
		return 
	End if 

	var $ex : Object:=$result.extraction
	var $summary : Text:="Event type: "+$ex.eventType

	If ($ex.eventDate#Null)
		$summary:=$summary+"\nDate: "+$ex.eventDate
	End if 
	If ($ex.guestCount#Null) && ($ex.guestCount>0)
		$summary:=$summary+"\nGuests: "+String($ex.guestCount)
	End if 
	If ($ex.venueCity#Null) && ($ex.venueCity#"")
		$summary:=$summary+"\nCity: "+$ex.venueCity
	End if 
	If (($ex.missingFields#Null) && ($ex.missingFields.length>0))
		$summary:=$summary+"\n⚠ Missing: "+$ex.missingFields.extract("field").join(", ")
	End if 

	OBJECT SET TITLE(*; "text_ai_status"; "✦ Quote extraction complete")
	OBJECT SET TITLE(*; "text_ai_context"; $summary)
	OBJECT SET TITLE(*; "text_ai_validation_badge"; "✓ JSON Validate: schema_quote_extraction OK")

	This.aiActions:=$result.actions
	This._renderActionButtons($result.actions)

Function _renderModificationResult($result : Object)
	If (Not($result.success))
		OBJECT SET TITLE(*; "text_ai_status"; "⚠ Analysis failed")
		OBJECT SET TITLE(*; "text_ai_context"; $result.validationError)
		return 
	End if 

	var $data : Object:=$result.impacts
	OBJECT SET TITLE(*; "text_ai_validation_badge"; "✓ JSON Validate: schema_modification_impacts OK")

	If ($result.ambiguous)
		OBJECT SET TITLE(*; "text_ai_status"; "⚠ Ambiguous – multiple events match")
		var $candText : Text:="Please select the correct event:\n"
		var $cand : Object
		For each ($cand; $data.candidateEvents)
			$candText:=$candText+"• "+$cand.contractRef+" – "+$cand.venueName+" ("+$cand.eventDate+")\n"
		End for each 
		OBJECT SET TITLE(*; "text_ai_context"; $candText)

		var $disambActions : Collection:=[]
		var $i : Integer
		var $c : Object
		var $maxDisamb : Integer:=$data.candidateEvents.length
		If ($maxDisamb>4)
			$maxDisamb:=4
		End if 
		For ($i; 0; $maxDisamb-1)
			$c:=$data.candidateEvents[$i]
			$disambActions.push({actionType: "resolve_ambiguity"; label: $c.contractRef+" – "+$c.venueName; params: {eventID: $c.eventID}})
		End for 
		This.aiActions:=$disambActions
		This._renderActionButtons($disambActions)
	Else 
		var $ctx : Text:=$data.modificationSummary
		If ($data.totalExtraCost#Null)
			$ctx:=$ctx+"\n\nTotal impact: "+String($data.totalExtraCost; "### ### ##0 €")
		End if 
		If ($data.requiresAvenant)
			$ctx:=$ctx+"\n⚠ Amendment required"
		End if 
		OBJECT SET TITLE(*; "text_ai_status"; "✦ "+String($data.impacts.length)+" impacts identified")
		OBJECT SET TITLE(*; "text_ai_context"; $ctx)

		// Utiliser les executionActions retournées par l'IA (avec hiddenPrompt)
		var $actions : Collection:=Choose(($data.executionActions#Null); $data.executionActions; [])
		If ($actions.length=0)
			// Fallback si pas d'executionActions
			If ($data.requiresAvenant)
				$actions.push({actionType: "send_avenant"; label: "📝 Send Amendment to Client"; description: $data.draftAvenantMessage; hiddenPrompt: ""})
			End if 
		End if 
		This.aiActions:=$actions
		This._renderActionButtons($actions)
	End if 

Function _renderActionButtons($actions : Collection)
	cs.UIHelpers.me.showActionButtons($actions)

Function _resetActionButtons()
	cs.UIHelpers.me.resetActionButtons()

Function _resetAIPanel()
	This._resetActionButtons()
	OBJECT SET TITLE(*; "text_ai_status"; "Click 'Analyze with AI' to start.")
	OBJECT SET TITLE(*; "text_ai_context"; "")

Function _executeAction($index : Integer)
	If ($index>=This.aiActions.length)
		return 
	End if 
	var $action : Object:=This.aiActions[$index]
	var $type : Text:=$action.actionType
	This._pendingActionIndex:=$index

	// Si l'action a un hiddenPrompt, utiliser le Temps 2 (tool calling)
	If (($action.hiddenPrompt#Null) && ($action.hiddenPrompt#""))
		This._executeWithToolCalling($action)
		return 
	End if 

	// Fallback pour les actions sans hiddenPrompt
	Case of 
		: ($type="draft_reply")
			var $draft : Text:=Choose(($action.description#Null); $action.description; "No draft available.")
			ALERT("📧 Draft reply:\n\n"+$draft)
		: ($type="resolve_ambiguity")
			ALERT("Action: "+$action.label)
		Else 
			ALERT("Action: "+$action.label)
	End case 

// ─── Temps 2 : Exécution avec tool calling + panneau confirm slide-in ────────
Function _executeWithToolCalling($action : Object)
	OBJECT SET TITLE(*; "text_ai_status"; "⏳ Searching services...")

	// Build context from identified event
	var $context : Object:={}
	If (This.event#Null)
		$context.eventID:=This.event.ID
		$context.eventDate:=String(This.event.eventDate; "yyyy-MM-dd")
		$context.guestCount:=This.event.guestCount
		If (This.event.venue#Null)
			$context.venueName:=This.event.venue.name
		End if 
		// Existing service lines for context
		$context.existingLines:=[]
		var $el : Object
		For each ($el; This.eventLines)
			$context.existingLines.push({ \
				serviceLabel: $el.serviceLabel; \
				quantity: $el.quantity; \
				unitPrice: $el.unitPrice \
			})
		End for each 
	Else 
		// Fallback: extract from AI result (quote path)
		If (This.aiResult#Null)
			If (This.aiResult.extraction#Null)
				var $ex : Object:=This.aiResult.extraction
				If ($ex.guestCount#Null)
					$context.guestCount:=$ex.guestCount
				End if 
				If ($ex.venueCity#Null)
					$context.venueName:=$ex.venueCity
				End if 
				If ($ex.eventDate#Null)
					$context.eventDate:=$ex.eventDate
				End if 
			End if 
			If (This.aiResult.impacts#Null)
				$context.eventID:=This.aiResult.impacts.eventID
				If ($context.eventID#"")
					var $analyzer : cs.EmailAnalyzer:=cs.EmailAnalyzer.me
					$context.existingLines:=$analyzer.buildEventLinesCollection($context.eventID)
				End if 
			End if 
		End if 
	End if 

	var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
	var $self : Object:=This
	var $act : Object:=$action
	var $ctx : Object:=$context
	$advisor.executeActionAsync($action.hiddenPrompt; $context; Formula($self._onExecutionDone($1; $act; $ctx)))

Function _onExecutionDone($execResult : Object; $action : Object; $context : Object)
	If (Form=Null)
		return 
	End if 

	If (Not($execResult.success))
		OBJECT SET TITLE(*; "text_ai_status"; "❌ "+$execResult.error)
		return 
	End if 

	If (($execResult.proposedLines=Null) || ($execResult.proposedLines.length=0))
		OBJECT SET TITLE(*; "text_ai_status"; "No services proposed.")
		return 
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

	// Store eventID on execResult so confirm handler can apply changes
	$execResult.eventID:=$context.eventID

	OBJECT SET TITLE(*; "text_ai_status"; "")
	This._showConfirmPanel($action; $execResult)

// ─── Confirm panel ────────────────────────────────────────────────────────────
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

Function _resizeWindow($width : Integer)
	var $curL; $curT; $curR; $curB : Integer
	GET WINDOW RECT($curL; $curT; $curR; $curB; Current form window)
	var $height : Integer:=$curB-$curT
	var $screenL; $screenT; $screenR; $screenB : Integer
	var $sL; $sT; $sR; $sB : Integer
	var $i : Integer
	$screenL:=0; $screenT:=0; $screenR:=0; $screenB:=0
	For ($i; 1; Count screens)
		SCREEN COORDINATES($sL; $sT; $sR; $sB; $i)
		If (($curL>=$sL) && ($curL<$sR))
			$screenL:=$sL; $screenT:=$sT; $screenR:=$sR; $screenB:=$sB
		End if 
	End for 
	If ($screenR=$screenL)
		SCREEN COORDINATES($screenL; $screenT; $screenR; $screenB)
	End if 
	If (($curL+$width)>$screenR)
		$curL:=$screenR-$width
		If ($curL<$screenL)
			$curL:=$screenL
		End if 
	End if 
	SET WINDOW RECT($curL; $curT; $curL+$width; $curT+$height; Current form window)

// ─── Event panel ─────────────────────────────────────────────────────────────
Function _loadEventLines()
	var $evt : cs.EventEntity:=This.event
	If ($evt=Null)
		return 
	End if 
	var $selection : cs.EventLineSelection:=ds.EventLine.query("eventID = :1"; $evt.ID)
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
			quantity: $line.quantity; \
			quantityStr: String($line.quantity); \
			unitPrice: $line.unitPrice; \
			totalStr: String($lineTotal; "### ### ##0 €") \
		})
	End for each 
	var $rentalPrice : Real:=Num($evt.venueRentalPrice)
	If ($rentalPrice>0)
		$total:=$total+$rentalPrice
		OBJECT SET TITLE(*; "text_ev_rental_val"; "Venue rental: "+String($rentalPrice; "### ### ##0 €"))
	Else 
		OBJECT SET TITLE(*; "text_ev_rental_val"; "")
	End if 
	OBJECT SET TITLE(*; "text_ev_total_val"; String($total; "### ### ##0 €"))

Function _setEventPanelVisible($visible : Boolean)
	OBJECT SET VISIBLE(*; "rect_email_sep"; $visible)
	OBJECT SET VISIBLE(*; "text_event_placeholder"; False)  // never show placeholder
	OBJECT SET VISIBLE(*; "rect_event_bg"; $visible)
	OBJECT SET VISIBLE(*; "rect_event_card"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_client_lbl"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_client_val"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_date_lbl"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_date_val"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_venue_lbl"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_venue_val"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_guests_lbl"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_guests_val"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_option_lbl"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_option_val"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_services_hdr"; $visible)
	OBJECT SET VISIBLE(*; "listbox_ev_lines"; $visible)
	OBJECT SET VISIBLE(*; "rect_ev_pricing_sep"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_rental_val"; $visible)
	OBJECT SET VISIBLE(*; "text_ev_total_val"; $visible)

Function _populateEventPanel()
	var $evt : cs.EventEntity:=This.event
	If ($evt=Null)
		return 
	End if 
	var $client : cs.ClientEntity:=ds.Client.query("ID = :1"; $evt.clientID).first()
	OBJECT SET TITLE(*; "text_ev_client_val"; Choose($client#Null; $client.companyName; "—"))
	OBJECT SET TITLE(*; "text_ev_date_val"; String($evt.eventDate; "dd/MM/yyyy"))
	OBJECT SET TITLE(*; "text_ev_guests_val"; String($evt.guestCount)+" guests")
	var $venue : cs.VenueEntity:=ds.Venue.query("ID = :1"; $evt.venueID).first()
	OBJECT SET TITLE(*; "text_ev_venue_val"; Choose($venue#Null; $venue.name+" – "+$venue.city; "—"))
	OBJECT SET TITLE(*; "text_ev_option_val"; Choose($evt.venueOption="indoor"; "🏢 Indoor"; "🌳 Outdoor"))


Function _getCatalog() : Collection
	If (This._catalog=Null)
		var $services : cs.ServiceSelection:=ds.Service.query("available = :1"; True)
		This._catalog:=[]
		var $svc : cs.ServiceEntity
		For each ($svc; $services)
			This._catalog.push({category: $svc.category; label: $svc.label; unit: $svc.unit; unitPrice: $svc.unitPrice})
		End for each 
	End if 
	return This._catalog

Function _aiSubtitle($type : Text) : Text
	Case of 
		: ($type="quote")
			return "Extract quote data, flag missing fields"
		: ($type="modification")
			return "Identify event & calculate impacts"
		Else 
			return "Read and summarize"
	End case 
