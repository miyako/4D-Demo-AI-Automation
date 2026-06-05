// AIAdvisor.4dm
// OpenAI call via AIKit Chat Helper + JSON Validate (Draft 2020-12)
// Uses the Chat Helper for automatic history and tools management
// All public methods are async (non-blocking via parameters.formula)
// Provider and model configured in AIProviders.json (model alias "chat")

property _client : Object
property _model : Text
property _chat : cs.AIKit.OpenAIChatHelper
property _windowID : Integer

Class constructor()
	This._model:="chat"  // model alias defined in AIProviders.json
	This._client:=cs.AIKit.OpenAI.new()

// ─── Factory: creates a configured Chat Helper ─────────────────────────────────
// Options are passed to chat.create() for correct initialization
Function _createChat($systemPrompt : Text; $schema : Object; $schemaName : Text; $formula : 4D.Function) : cs.AIKit.OpenAIChatHelper
	var $options:=cs.AIKit.OpenAIChatCompletionsParameters.new()
	$options.model:=This._model
	$options.temperature:=0.2
	$options.max_completion_tokens:=2048
	$options.formula:=$formula
	If ($schema#Null)
		$options.response_format:={type: "json_schema"; json_schema: { \
			name: $schemaName; \
			schema: $schema; \
			strict: True \
		}}
	End if 
	return This._client.chat.create($systemPrompt; $options)

// ═══════════════════════════════════════════════════════════════════════════════
// ─── ASYNC API (Chat Helper + formula) ────────────────────────────────────────
// All methods return immediately.
// The callback (4D.Function) is invoked in the form event loop.
// Pattern: $self:=This + Formula($self._onXxx($1; captured_params...))
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Scenario 2: Weather alert on an event ─────────────────────────────────────
// $callback receives {success; weatherActions; validationError}
Function analyzeWeatherRiskAsync($event : cs.EventEntity; $callback : 4D.Function)
	var $schemaWeather : Object:=This._loadSchema("schema_weather_actions.json")
	If ($schemaWeather=Null)
		$callback.call(Null; {success: False; weatherActions: Null; validationError: "Impossible de charger schema_weather_actions.json"})
		return 
	End if 

	var $servicesSnippet : Text:=""
	var $line : cs.EventLineEntity
	For each ($line; $event.lines)
		$servicesSnippet:=$servicesSnippet+"- "+$line.serviceLabel+" (qty: "+String($line.quantity)+")\n"
	End for each 

	var $venue : cs.VenueEntity:=$event.venue
	var $venueInfo : Text
	If ($venue#Null)
		$venueInfo:=$venue.name+" - "+$venue.city+", "+$venue.country+" ("+$venue.venueType+")"
		$venueInfo:=$venueInfo+" | Event option: "+$event.venueOption
	// Mention indoor alternative if available — explicitly state absence otherwise
	If ($event.venueOption="outdoor")
		If ($venue.indoorOption#Null)
			$venueInfo:=$venueInfo+"\nIndoor alternative available at same venue: "+$venue.indoorOption.name+" (capacity: "+String($venue.indoorOption.capacity)+", rental: "+String($venue.indoorOption.rentalPrice)+"€)"
		Else 
			$venueInfo:=$venueInfo+"\nNo indoor alternative at this venue."
		End if 
	End if 
	Else 
		$venueInfo:="[No venue]"
	End if 

	var $weatherData : Object:=$event.weatherAlertJson.weatherData

	var $system : Text:="You are a risk management specialist for Event Pulse, an international event agency. "
	$system:=$system+"Analyze weather conditions for an upcoming event and compare them with the event's planned weather setup.\n\n"
	$system:=$system+"The event has a 'weatherSetup' describing what weather it was planned for:\n"
	$system:=$system+"- conditions: 'indifferent' (indoor, weather doesn't matter), 'sunny' (planned for fair weather), 'rain' (already prepared for rain)\n"
	$system:=$system+"- temperature: 'normal', 'cold' (cold-weather gear planned), 'hot' (heat management planned)\n\n"
	$system:=$system+"IMPORTANT: Every action you propose MUST be a concrete operation on services or the venue setup. "
	$system:=$system+"NEVER propose passive or monitoring actions ('monitor weather', 'watch updates', 'check again', etc.). "
	$system:=$system+"Valid actionType values: 'add_services', 'remove_services', 'replace_services', 'switch_venue'.\n\n"
	$system:=$system+"Your analysis MUST:\n"
	$system:=$system+"1) Compare the forecast with the planned weatherSetup to assess if current services are adequate\n"
	$system:=$system+"2) In the 'summary' field, explain in 2-4 sentences: what weather was planned for, what's actually forecast, "
	$system:=$system+"whether current services match or mismatch, and what should change. Be specific about which booked services are affected.\n"
	$system:=$system+"3) If forecast is WORSE than planned (e.g., planned sunny but rain forecast): propose adding weather protection services (tents, waterproof covers, drainage, etc.)\n"
	$system:=$system+"4) If forecast is BETTER than planned (e.g., planned rain but sunny forecast): propose removing now-unnecessary rain services and replacing them with fair-weather upgrades\n"
	$system:=$system+"5) If forecast matches the plan: propose service optimizations (upgrade quality, add comfort services matching the weather, adjust quantities). Do NOT suggest monitoring.\n"
	$system:=$system+"6) For indoor/indifferent venues: only flag extreme conditions (storms, extreme heat/cold) and propose relevant services (extra heating, cooling, guest transport cover)\n"
	$system:=$system+"7) SWITCH_VENUE rules (STRICT):\n"
	$system:=$system+"   - Only propose 'switch_venue' if the venue info explicitly says 'Indoor alternative available at same venue'.\n"
	$system:=$system+"   - NEVER propose 'switch_venue' if the venue info says 'No indoor alternative at this venue'.\n"
	$system:=$system+"   - NEVER propose 'switch_venue' if the event venueOption is already 'indoor'.\n"
	$system:=$system+"   - When proposing switch_venue for rain/storm: it is MANDATORY to include it when an indoor alternative IS available.\n"
	$system:=$system+"   - When 'switch_venue' is proposed: do NOT also propose a 'replace_services' for outdoor-to-indoor substitution — switch_venue already handles all service replacement.\n"
	$system:=$system+"8) Propose 2 to 4 distinct actions covering different strategies (e.g., add rain protection AND switch to indoor). Do NOT merge everything into a single action.\n\n"
	$system:=$system+"For each action, include a 'hiddenPrompt' describing what contingency services to search for, quantities needed, and weather-specific requirements. "
	$system:=$system+"Example hiddenPrompt: 'Search for weather protection structures: large tent or pagoda for 150 guests, waterproof flooring, portable heating units x2.'\n"
	$system:=$system+"CRITICAL for 'replace_services' actions: the hiddenPrompt MUST contain two explicit sections:\n"
	$system:=$system+"  Section REMOVE: list exact labels of existing services to remove (copy them verbatim from the event's services list), e.g. 'REMOVE: Poncho pluie jetable (lot de 50) x3, Parapluie personnalisé événement x43'\n"
	$system:=$system+"  Section SEARCH: describe what replacement services to search in the catalog, e.g. 'SEARCH: outdoor lounge furniture for 86 guests, comfort seating'\n"
	$system:=$system+"Respond ONLY with a valid JSON object: {\"summary\": \"...\", \"actions\": [...]}.'\n"
	$system:=$system+"Each action has only: actionType, label, hiddenPrompt."

	var $user : Text:="Event ID: "+$event.ID+"\n"
	$user:=$user+"Event Date: "+String($event.eventDate; "yyyy-MM-dd")+"\n"
	$user:=$user+"Venue: "+$venueInfo+"\n"
	$user:=$user+"Guest Count: "+String($event.guestCount)+"\n\n"

	// Planned weather setup for this event
	var $setup : Object:=$event.weatherSetup
	If ($setup#Null)
		$user:=$user+"Planned Weather Setup:\n"
		$user:=$user+"- Conditions: "+$setup.conditions+" ("+($setup.conditions="indifferent" ? "indoor/weather-independent" : ($setup.conditions="sunny" ? "planned for fair weather" : "already prepared for rain"))+")\n"
		$user:=$user+"- Temperature: "+$setup.temperature+" ("+($setup.temperature="normal" ? "standard setup" : ($setup.temperature="cold" ? "cold-weather equipment included" : "heat management included"))+")\n\n"
	Else 
		$user:=$user+"Planned Weather Setup: not specified (assume sunny/normal)\n\n"
	End if 

	$user:=$user+"Weather Forecast:\n"
	$user:=$user+JSON Stringify($weatherData)+"\n\n"
	$user:=$user+"Booked Services:\n"+$servicesSnippet+"\n"
	$user:=$user+"Return the weather risk analysis with summary and 2-4 recommended actions covering diverse strategies."

	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	This._chat:=This._createChat($system; $schemaWeather; "weather_actions"; Formula($self._onChatDone($1; $cb; "schema_weather_actions.json")))
	This._chat.prompt($user)

// ─── Scenario 3: Client modification email linked to a known event ──────────
// The event is already identified — no need to disambiguate.
// $callback receives {success; impacts; validationError}
Function analyzeLinkedEmailAsync($email : cs.EmailEntity; $event : cs.EventEntity; $callback : 4D.Function)
	var $schemaImpacts : Object:=This._loadSchema("schema_modification_impacts.json")
	If ($schemaImpacts=Null)
		$callback.call(Null; {success: False; impacts: Null; validationError: "Cannot load schema_modification_impacts.json"})
		return 
	End if 

	var $venue : cs.VenueEntity:=$event.venue
	var $eventText : Text:="Contract: "+$event.contractRef
	$eventText:=$eventText+" | Date: "+String($event.eventDate; "yyyy-MM-dd")
	$eventText:=$eventText+" | Venue: "+($venue ? $venue.name : "?")
	$eventText:=$eventText+" | Guests: "+String($event.guestCount)

	var $linesText : Text:=""
	var $line : cs.EventLineEntity
	For each ($line; $event.lines)
		$linesText:=$linesText+"- [ID:"+String($line.serviceID)+"] "+$line.serviceLabel+" × "+String($line.quantity)+" @ "+String($line.unitPrice)+"€/u\n"
	End for each 

	var $system : Text:="You are a contract specialist for Event Pulse. "
	$system:=$system+"A client has sent a message about a confirmed event. The event is already identified. "
	$system:=$system+"Your task is to identify ONLY requests that require an actual change to the contracted services (add, remove, or replace a service line). "
	$system:=$system+"IGNORE: questions, confirmations, reassurances, logistical inquiries, or requests that do not change what is on the contract. "
	$system:=$system+"Examples of what to IGNORE: 'please confirm heating is included', 'does the team have experience outdoors?', 'will the venue be ready on time?'. "
	$system:=$system+"Examples of what to ACT ON: 'switch the buffet to a plated dinner', 'add a photo booth', 'remove the DJ'.\n"
	$system:=$system+"Valid actionType values: 'add_services', 'remove_services', 'replace_services', 'switch_venue'.\n"
	$system:=$system+"For each action, write a 'hiddenPrompt' describing precisely:\n"
	$system:=$system+"- For removes: exact service labels from the existing services list to remove\n"
	$system:=$system+"- For adds/replace: what services to SEARCH for and ADD (only if plausibly in a standard event catalog)\n"
	$system:=$system+"- For replace: use format 'REMOVE: <labels>\nSEARCH: <what to find>'\n"
	$system:=$system+"Keep 'label' short (button text, 3-5 words max).\n"
	$system:=$system+"If the email contains NO actionable service changes, return an empty actions array [].\n"
	$system:=$system+"Also write a brief 'summary' (1-2 sentences) describing what the client requested.\n"
	$system:=$system+"Respond ONLY with a valid JSON object: {\"summary\": \"...\", \"actions\": [...]}. No markdown."

	var $user : Text:="From: "+$email.sender+" <"+$email.senderEmail+">"
	$user:=$user+"\nSubject: "+$email.subject+"\n\n"
	$user:=$user+"Body:\n"+$email.body+"\n\n"
	$user:=$user+"Event: "+$eventText+"\n"
	If ($event.lines.length>0)
		$user:=$user+"\nCurrent services:\n"+$linesText
	End if 

	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	This._chat:=This._createChat($system; $schemaImpacts; "modification_impacts"; Formula($self._onChatDone($1; $cb; "schema_modification_impacts.json")))
	This._chat.prompt($user)

// ─── generateDraftEmail: confirmation email after applying an action ──────────
// $callback receives {success; emailText; validationError}
// $context: optional {weatherExplanation, weatherForecast, clientEmail: {subject, body, sender}}
Function generateDraftEmailAsync($event : cs.EventEntity; $action : Object; $proposedLines : Collection; $context : Object; $callback : 4D.Function)
	var $schemaDraft : Object:=This._loadSchema("schema_draft_email.json")
	If ($schemaDraft=Null)
		$callback.call(Null; {success: False; emailText: ""; validationError: "Cannot load schema_draft_email.json"})
		return 
	End if 

	var $venue : cs.VenueEntity:=$event.venue
	var $venueInfo : Text:=$venue ? $venue.name+", "+$venue.city : "?"
	var $client : cs.ClientEntity:=$event.client
	var $clientName : Text:=$client ? $client.contactName : "Client"

	var $linesText : Text:=""
	var $line : Object
	For each ($line; $proposedLines)
		var $lineTotal : Real:=Num($line.quantity)*Num($line.unitPrice)
		$linesText:=$linesText+"- "+String($line.label)+" × "+String($line.quantity)+" @ "+String($line.unitPrice)+"€ = "+String($lineTotal)+"€\n"
	End for each 

	var $system : Text:="You are an event coordinator at Event Pulse drafting a professional email to a client about PROPOSED service changes. "
	$system:=$system+"Write a clear, professional email in the language typically used with the client. "
	$system:=$system+"Address the client by first name. Be concise and positive. "
	$system:=$system+"IMPORTANT: these are PROPOSED changes, NOT yet applied. Use conditional language: 'we would like to propose', 'we recommend', 'subject to your approval', 'pending your confirmation'. Do NOT write as if changes are already done. "
	$system:=$system+"Do NOT include subject line or headers — just the email body text. "
	$system:=$system+"Respond ONLY with a valid JSON object matching the schema: {\"emailText\": \"...\"}."

	var $user : Text:="Client: "+$clientName+"\n"
	$user:=$user+"Event: "+$event.contractRef+" — "+String($event.eventDate; "yyyy-MM-dd")+" at "+$venueInfo+" ("+String($event.guestCount)+" guests)\n\n"
	If (($context#Null) && ($context.clientEmail#Null))
		$user:=$user+"=== ORIGINAL CLIENT EMAIL ===\n"
		$user:=$user+"From: "+String($context.clientEmail.sender)+"\n"
		$user:=$user+"Subject: "+String($context.clientEmail.subject)+"\n"
		$user:=$user+"Body:\n"+String($context.clientEmail.body)+"\n\n"
	End if 
	If (($context#Null) && ($context.weatherExplanation#Null))
		$user:=$user+"=== WEATHER ALERT CONTEXT ===\n"
		$user:=$user+String($context.weatherExplanation)+"\n\n"
	End if 
	If ($action#Null)
		$user:=$user+"=== PROPOSED ACTION ===\n"
		$user:=$user+"Action: "+String($action.label)+"\n"
		If (($action.hiddenPrompt#Null) && ($action.hiddenPrompt#""))
			$user:=$user+"Details: "+String($action.hiddenPrompt)+"\n"
		End if 
		$user:=$user+"\n"
	End if 
	If ($linesText#"")
		$user:=$user+"Proposed service changes:\n"+$linesText+"\n"
	End if 
	$user:=$user+"Draft a short professional email to the client presenting these proposed changes and asking for their confirmation."

	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	This._chat:=This._createChat($system; $schemaDraft; "draft_email"; Formula($self._onGenerateDraftEmailDone($1; $cb)))
	This._chat.prompt($user)

Function _onGenerateDraftEmailDone($chatResult : Object; $callback : 4D.Function)
	If (($chatResult#Null) && (Not($chatResult.terminated)))
		return 
	End if 
	var $result : Object:={success: False; emailText: ""; validationError: ""}
	var $parsed : Object:=This._extractParsedResponse($chatResult)
	If ($parsed=Null)
		$result.validationError:="schema_draft_email: "+This._extractError($chatResult)
		$callback.call(Null; $result)
		return 
	End if 
	$result.validation:=This._validateResponse($parsed; "schema_draft_email.json")
	If (Not($result.validation.success))
		$result.validationError:="schema_draft_email: "+JSON Stringify($result.validation.errors)
		$callback.call(Null; $result)
		return 
	End if 
	$result.success:=True
	$result.rawAiResponse:=JSON Parse(JSON Stringify($parsed))
	$result.emailText:=$parsed.emailText
	$callback.call(Null; $result)

// ─── draft_reply: AI generates email text for client ─────────────────────────
// $callback receives {success; draft; error}
// ─── Re-evaluation of remaining actions after applying an action ────────────────
// $callback receives {success; actions; validationError}
Function reassessActionsAsync($remainingActions : Collection; $appliedLabel : Text; $event : cs.EventEntity; $callback : 4D.Function)
	var $schemaReassess : Object:=This._loadSchema("schema_reassess_actions.json")
	If ($schemaReassess=Null)
		$callback.call(Null; {success: False; actions: []; validationError: "Cannot load schema_reassess_actions.json"})
		return 
	End if 

	var $servicesSnippet : Text:=""
	var $line : cs.EventLineEntity
	For each ($line; $event.lines)
		$servicesSnippet:=$servicesSnippet+"- "+$line.serviceLabel+" × "+String($line.quantity)+" @ "+String($line.unitPrice)+"€\n"
	End for each 

	var $actionsSnippet : Text:=""
	var $action : Object
	For each ($action; $remainingActions)
		$actionsSnippet:=$actionsSnippet+"- ["+$action.actionType+"] "+$action.label+"\n"
	End for each 

	var $system : Text:="You are a risk management specialist for Event Pulse. "
	$system:=$system+"An action has just been applied to an event. Re-evaluate the remaining proposed actions to determine which are still relevant.\n\n"
	$system:=$system+"For each remaining action, decide:\n"
	$system:=$system+"- Keep it if it's still needed given the updated service list\n"
	$system:=$system+"- Drop it if the applied action already resolves what it was targeting\n"
	$system:=$system+"- Adjust its hiddenPrompt if the situation has changed\n\n"
	$system:=$system+"NEVER propose passive monitoring actions. Only concrete service operations.\n"
	$system:=$system+"Return ONLY the actions that are still relevant. If all issues are resolved, return an empty actions array.\n"
	$system:=$system+"Respond ONLY with a valid JSON object matching the reassess_actions schema."

	var $user : Text:="Action just applied: "+$appliedLabel+"\n\n"
	$user:=$user+"Current services on event (after applying action):\n"+$servicesSnippet+"\n"
	$user:=$user+"Remaining actions to reassess:\n"+$actionsSnippet+"\n"
	$user:=$user+"Return only the actions that are still necessary."

	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	This._chat:=This._createChat($system; $schemaReassess; "reassess_actions"; Formula($self._onChatDone($1; $cb; "schema_reassess_actions.json")))
	This._chat.prompt($user)

// ─── Shared chat completion handler ──────────────────────────────────────────
// Result: {success; summary; actions; rawAiResponse; validationError; validation}
Function _onChatDone($chatResult : Object; $callback : 4D.Function; $schemaFile : Text)
	If (($chatResult#Null) && (Not($chatResult.terminated)))
		return 
	End if 
	var $result : Object:={success: False; summary: ""; actions: []; rawAiResponse: Null; validationError: ""; validation: Null}
	var $parsed : Object:=This._extractParsedResponse($chatResult)
	If ($parsed=Null)
		$result.validationError:=$schemaFile+": "+This._extractError($chatResult)
		$callback.call(Null; $result)
		return 
	End if 
	$result.validation:=This._validateResponse($parsed; $schemaFile)
	If (Not($result.validation.success))
		$result.validationError:=$schemaFile+": "+JSON Stringify($result.validation.errors)
		$callback.call(Null; $result)
		return 
	End if 
	$result.success:=True
	$result.rawAiResponse:=JSON Parse(JSON Stringify($parsed))
	$result.summary:=String($parsed.summary)
	$result.actions:=$parsed.actions
	$callback.call(Null; $result)

// ─── Step 2: Execution with tool calling (ChatHelper + registerTools) ───────────
// $callback receives {success; proposedLines; summary; error}
Function executeActionAsync($hiddenPrompt : Text; $context : Object; $callback : 4D.Function)
	var $system : Text:="You are an event service execution assistant for Event Pulse.\n"
	$system:=$system+"Use the search_services tool to find services in the catalog, then build a list of proposed changes.\n\n"
	$system:=$system+"Delta rules:\n"
	$system:=$system+"- 'add': a new service found via search_services\n"
	$system:=$system+"- 'remove': an EXISTING service — take serviceID directly from the existing services list, do NOT search\n"
	$system:=$system+"- 'update': change the quantity of an existing service\n\n"
	$system:=$system+"For 'replace_services' tasks: emit BOTH 'remove' lines (from REMOVE: section) AND 'add' lines (from SEARCH: section).\n"
	$system:=$system+"NEVER add a service that is already in the existing list with the same label or serviceID.\n"
	$system:=$system+"MEAL RULE: if adding an upgraded meal and an existing meal service is already booked, emit a 'remove' for the existing one first.\n"
	$system:=$system+"If search_services returns no results: return empty proposedLines.\n"
	$system:=$system+"For 'remove' lines: the serviceID MUST be the [ID:xxx] value from the existing services list.\n"
	$system:=$system+"Summary: 1-2 sentences, use 'We propose...' — not past tense.\n"
	$system:=$system+"Do NOT include label, category, unitPrice — resolved server-side.\n"
	If ($context.eventDate#Null)
		$system:=$system+"\nEvent: "+$context.eventDate
		If ($context.guestCount#Null)
			$system:=$system+", "+String($context.guestCount)+" guests"
		End if 
		If ($context.venueName#Null)
			$system:=$system+", "+$context.venueName
		End if 
		$system:=$system+"\n"
	End if 
	If (($context.existingLines#Null) && ($context.existingLines.length>0))
		$system:=$system+"Existing services:\n"
		var $el : Object
		For each ($el; $context.existingLines)
			$system:=$system+"- [ID:"+String($el.serviceID)+"] "+$el.serviceLabel+" × "+String($el.quantity)+" @ "+String($el.unitPrice)+"€\n"
		End for each 
	End if 

	var $execSchema : Object:=This._loadSchema("schema_action_execution.json")
	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	This._windowID:=($context.windowID#Null) ? $context.windowID : 0
	This._chat:=This._createChat($system; $execSchema; "action_execution"; Formula($self._onExecutionChatDone($1; $cb)))
	var $searchTool : cs.Tool_SearchServices:=cs.Tool_SearchServices.new()
	var $td : Object
	For each ($td; $searchTool.tools)
		$td.handler:=$searchTool
	End for each 
	This._chat.registerTools($searchTool.tools)
	This._chat.prompt($hiddenPrompt)

Function _onExecutionChatDone($chatResult : Object; $callback : 4D.Function)
	If (($chatResult#Null) && (Not($chatResult.terminated)))
		return 
	End if 
	var $result : Object:={success: False; proposedLines: Null; summary: ""; error: ""; validation: Null}
	var $parsed : Object:=This._extractParsedResponse($chatResult)

	// Debug: log full parsed result
	var $logFile : 4D.File:=Folder(fk logs folder).file("execution_result.json")
	$logFile.setText(JSON Stringify({parsed: $parsed; choice: $chatResult.choice}; *))

	If ($parsed=Null)
		$result.error:=This._extractError($chatResult)
		$callback.call(Null; $result)
		return 
	End if 
	// JSON Validate on the 4D side — post-AI safety net (blog pattern)
	$result.validation:=This._validateResponse($parsed; "schema_action_execution.json")
	If (Not($result.validation.success))
		$result.error:="schema_action_execution: "+JSON Stringify($result.validation.errors)
		$callback.call(Null; $result)
		return 
	End if 
	$result.success:=True
	$result.rawAiResponse:=JSON Parse(JSON Stringify($parsed))  // snapshot before enrichment — used by debug display
	$result.proposedLines:=This._enrichProposedLines($parsed.proposedLines)
	$result.summary:=$parsed.summary
	$callback.call(Null; $result)

// ═══════════════════════════════════════════════════════════════════════════════
// ─── HELPERS ──────────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Enriches proposed lines with label/category/unitPrice ──────────────────────
// For 'remove' lines: use actual booked price from session singleton (event-specific).
// For 'add' lines: use catalog price from ds.Service.
Function _enrichProposedLines($lines : Collection) : Collection
	If ($lines=Null)
		return []
	End if 
	// Retrieve existing event lines from session singleton (set by FC_EventDetail before worker call)
	var $existingLines : Collection:=cs.AIWorkerContext.me.getExistingLines(This._windowID)
	var $line : Object
	For each ($line; $lines)
		var $svc : cs.ServiceEntity:=ds.Service.get($line.serviceID)
		If ($svc#Null)
			$line.label:=$svc.label
			$line.category:=$svc.category
			// For removes, prefer actual booked price over catalog price
			If ($line.delta="remove")
				var $booked : Object:=Null
				var $el : Object
				For each ($el; $existingLines)
					If ($el.serviceID=$line.serviceID)
						$booked:=$el
						break
					End if 
				End for each 
				$line.unitPrice:=($booked#Null) ? Num($booked.unitPrice) : $svc.unitPrice
			Else 
				$line.unitPrice:=$svc.unitPrice
			End if 
		Else 
			$line.label:="[unknown:"+String($line.serviceID)+"]"
			$line.category:=""
			$line.unitPrice:=0
		End if 
	End for each 
	return $lines

// ─── Extracts and parses JSON from the chat response ────────────────────────────
Function _extractParsedResponse($chatResult : Object) : Object
	If ($chatResult=Null) || (Not($chatResult.success))
		return Null
	End if 
	If ($chatResult.choice=Null)
		var $dump : Text:=JSON Stringify($chatResult; *)
		var $logFile : 4D.File:=Folder(fk logs folder).file("openai_error.json")
		$logFile.setText($dump)
		return Null
	End if 
	var $content : Text:=$chatResult.choice.message.content
	If ($content="")
		return Null
	End if 
	return JSON Parse($content)

// ─── Extracts a readable error message from the chat response ───────────────────
Function _extractError($chatResult : Object) : Text
	If ($chatResult=Null)
		return "API call returned Null"
	End if 
	If (Not($chatResult.success))
		If ($chatResult.errors#Null)
			return JSON Stringify($chatResult.errors)
		End if 
		return "API call failed"
	End if 
	If ($chatResult.choice=Null)
		return "No choice in response"
	End if 
	return "Empty or invalid JSON response"

// ─── JSON Validation on the 4D side (illustrates the "Making AI Predictable" blog) ─
// Validates the parsed AI response against the Draft 2020-12 schema.
// Retourne {success; errors; schemaName}
Function _validateResponse($parsed : Object; $schemaFilename : Text) : Object
	var $schema : Object:=This._loadSchema($schemaFilename)
	If ($schema=Null)
		return {success: False; errors: [{message: "Cannot load schema: "+$schemaFilename}]; schemaName: $schemaFilename}
	End if 
	var $validation : Object:=JSON Validate($parsed; $schema)
	return {success: $validation.success; errors: $validation.errors; schemaName: $schemaFilename}

// ─── Schema loading from Resources/schemas ─────────────────────────────────────
Function _loadSchema($filename : Text) : Object
	var $file : 4D.File:=Folder(fk resources folder).file("schemas/"+$filename)
	If (Not($file.exists))
		return Null
	End if 
	return JSON Parse($file.getText())

// ─── Prompt builders (called from FC_EventDetail before tool-calling dispatch) ──

// Builds the switch_venue execution prompt for _executeSwitchVenue
Function switchVenuePrompt($event : cs.EventEntity) : Text
	var $venue : cs.VenueEntity:=$event.venue
	var $indoorName : Text:=($venue#Null) && ($venue.indoorOption#Null) ? String($venue.indoorOption.name) : "indoor option"
	var $indoorRental : Real:=($venue#Null) && ($venue.indoorOption#Null) ? Num($venue.indoorOption.rentalPrice) : 0
	var $guestCount : Integer:=$event.guestCount
	
	var $allServices : Text:=""
	var $removedTotal : Real:=0
	var $line : cs.EventLineEntity
	For each ($line; $event.lines)
		$allServices:=$allServices+"- [ID:"+String($line.serviceID)+"] "+$line.serviceLabel+" x"+String($line.quantity)+" @ "+String($line.unitPrice)+"€\n"
		$removedTotal:=$removedTotal+($line.quantity*$line.unitPrice)
	End for each 
	
	var $maxBudget : Real:=($removedTotal-$indoorRental)*1.10
	
	var $prompt : Text:="Switch this outdoor event to the indoor venue '"+$indoorName+"' (rental: "+String($indoorRental)+"€).\n\n"
	$prompt:=$prompt+"Current booked services:\n"+$allServices+"\n"
	$prompt:=$prompt+"Step 1 — REMOVE: Identify and remove all outdoor-specific services (tents, outdoor structures, outdoor sound/lighting, rain gear, patio heaters, outdoor venue rental, outdoor power/generators, etc.). Use [ID:xxx] from the list above.\n\n"
	$prompt:=$prompt+"Step 2 — Indoor rental: The indoor venue rental ("+String($indoorRental)+"€) will be added automatically. Do NOT search for it.\n\n"
	$prompt:=$prompt+"Step 3 — COMPUTE: Calculate freed_budget = SUM(removed services cost) - "+String($indoorRental)+"€ (indoor rental).\n\n"
	$prompt:=$prompt+"Step 4 — ADD indoor services (ONLY if freed_budget > 0):\n"
	$prompt:=$prompt+"  Search for indoor-compatible services (sound system, lighting, decor, comfort) appropriate for "+String($guestCount)+" guests.\n"
	$prompt:=$prompt+"  STRICT BUDGET: total cost of ADD lines must NOT exceed freed_budget × 1.10 (max budget: "+String($maxBudget)+"€).\n"
	$prompt:=$prompt+"  Stop searching once budget is reached. Only add what is genuinely useful.\n"
	$prompt:=$prompt+"  If freed_budget <= 0: skip this step entirely.\n"
	return $prompt

// Builds the fill services prompt for the second round of switch_venue
Function fillServicesPrompt($event : cs.EventEntity; $budget : Real) : Text
	var $venue : cs.VenueEntity:=$event.venue
	var $indoorName : Text:=($venue#Null) && ($venue.indoorOption#Null) ? String($venue.indoorOption.name) : "indoor venue"
	var $prompt : Text:="Find indoor-compatible services to add for an event with "+String($event.guestCount)+" guests at '"+$indoorName+"'.\n"
	$prompt:=$prompt+"STRICT BUDGET: total cost of ADD lines must NOT exceed "+String($budget)+"€.\n"
	$prompt:=$prompt+"Search for services like: indoor sound, lighting/decor, comfort, entertainment. Stop once budget is reached.\n"
	$prompt:=$prompt+"Do NOT add venue rental. Do NOT add services already being removed or already in the existing services list."
	return $prompt

