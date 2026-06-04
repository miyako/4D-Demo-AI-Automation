// AIAdvisor.4dm
// OpenAI call via AIKit Chat Helper + JSON Validate (Draft 2020-12)
// Uses the Chat Helper for automatic history and tools management
// All public methods are async (non-blocking via parameters.formula)
// Provider and model configured in AIProviders.json (model alias "chat")

property _client : Object
property _model : Text
property _chat : cs.AIKit.OpenAIChatHelper

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

// ─── Scenario 1: Email analysis = quote request ────────────────────────────────
// $callback receives {success; extraction; actions; validationError}
Function analyzeQuoteEmailAsync($email : cs.EmailEntity; $catalog : Collection; $callback : 4D.Function)
	var $schemaCombined : Object:=This._loadSchema("schema_quote_combined.json")
	If ($schemaCombined=Null)
		$callback.call(Null; {success: False; extraction: Null; actions: Null; validationError: "Impossible de charger schema_quote_combined.json"})
		return 
	End if 

	var $catalogSnippet : Text:=This._buildCatalogSnippet($catalog)

	var $system : Text:="You are an expert event planning assistant working for an international event agency called Event Pulse. "
	$system:=$system+"Your task is to analyze a client email that is a quote request and return a STRICT JSON object. "
	$system:=$system+"Respond ONLY with the JSON — no markdown, no explanation.\n\n"
	$system:=$system+"Return TWO top-level keys:\n"
	$system:=$system+"1) 'extraction': the quote data (eventType, missingFields, etc.)\n"
	$system:=$system+"2) 'actions': an array of recommended actions (max 4)\n\n"
	$system:=$system+"For each action, you MUST include a 'hiddenPrompt' field. This is an internal prompt that will be sent back to an AI assistant with access to a service catalog search tool. "
	$system:=$system+"The hiddenPrompt must describe in detail: what services to search for, estimated quantities based on guest count, and any specific constraints. "
	$system:=$system+"Example: 'Search for catering services for a seated dinner for 200 guests, including appetizers, main course, dessert. Also search for table setup and linens for 25 round tables.'\n\n"
	$system:=$system+"For 'extraction':\n"
	$system:=$system+"- 'eventType' is REQUIRED (e.g. 'seminar', 'gala', 'product launch', 'conference')\n"
	$system:=$system+"- 'missingFields' is REQUIRED: list fields not found in the email\n"
	$system:=$system+"- Use null for optional fields not found in the email\n\n"
	$system:=$system+"Available services in our catalog (excerpt):\n"+$catalogSnippet

	var $user : Text:="Client email subject: "+$email.subject+"\n"
	$user:=$user+"From: "+$email.sender+" <"+$email.senderEmail+">\n\n"
	$user:=$user+"Body:\n"+$email.body+"\n\n"
	$user:=$user+"Extract quote information and propose 2-4 concrete actions."

	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	This._chat:=This._createChat($system; $schemaCombined; "quote_extraction"; Formula($self._onQuoteChatDone($1; $cb)))
	This._chat.prompt($user)

Function _onQuoteChatDone($chatResult : Object; $callback : 4D.Function)
	If (($chatResult#Null) && (Not($chatResult.terminated)))
		return 
	End if 
	var $result : Object:={success: False; extraction: Null; actions: Null; validationError: ""; validation: Null}
	var $parsed : Object:=This._extractParsedResponse($chatResult)
	If ($parsed=Null)
		$result.validationError:=This._extractError($chatResult)
		$callback.call(Null; $result)
		return 
	End if 
	// JSON Validate on the 4D side — post-AI safety net (blog pattern)
	$result.validation:=This._validateResponse($parsed; "schema_quote_combined.json")
	If (Not($result.validation.success))
		$result.validationError:="schema_quote_combined: "+JSON Stringify($result.validation.errors)
		$callback.call(Null; $result)
		return 
	End if 
	$result.success:=True
	$result.extraction:=$parsed.extraction
	$result.actions:=$parsed.actions
	$callback.call(Null; $result)

// ─── Scenario 2: Weather alert on an event ─────────────────────────────────────
// $callback receives {success; weatherActions; validationError}
Function analyzeWeatherRiskAsync($event : cs.EventEntity; $weatherData : Object; $eventLines : Collection; $callback : 4D.Function)
	var $schemaWeather : Object:=This._loadSchema("schema_weather_actions.json")
	If ($schemaWeather=Null)
		$callback.call(Null; {success: False; weatherActions: Null; validationError: "Impossible de charger schema_weather_actions.json"})
		return 
	End if 

	var $servicesSnippet : Text:=""
	var $line : Object
	For each ($line; $eventLines)
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

	var $system : Text:="You are a risk management specialist for Event Pulse, an international event agency. "
	$system:=$system+"Analyze weather conditions for an upcoming event and compare them with the event's planned weather setup.\n\n"
	$system:=$system+"The event has a 'weatherSetup' describing what weather it was planned for:\n"
	$system:=$system+"- conditions: 'indifferent' (indoor, weather doesn't matter), 'sunny' (planned for fair weather), 'rain' (already prepared for rain)\n"
	$system:=$system+"- temperature: 'normal', 'cold' (cold-weather gear planned), 'hot' (heat management planned)\n\n"
	$system:=$system+"IMPORTANT: Every action you propose MUST be a concrete operation on services or the venue setup. "
	$system:=$system+"NEVER propose passive or monitoring actions ('monitor weather', 'watch updates', 'check again', etc.). "
	$system:=$system+"Valid actionType values: 'add_services', 'remove_services', 'replace_services', 'switch_venue', 'notify_client'.\n\n"
	$system:=$system+"Your analysis MUST:\n"
	$system:=$system+"1) Compare the forecast with the planned weatherSetup to assess if current services are adequate\n"
	$system:=$system+"2) In the 'explanation' field, explain in 3-5 sentences: what weather was planned for, what's actually forecast, "
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
	$system:=$system+"8) Propose 2 to 4 distinct actions covering different strategies (e.g., add rain protection AND switch to indoor AND replace services). Do NOT merge everything into a single action.\n\n"
	$system:=$system+"For each action, include a 'hiddenPrompt' describing what contingency services to search for, quantities needed, and weather-specific requirements. "
	$system:=$system+"Example hiddenPrompt: 'Search for weather protection structures: large tent or pagoda for 150 guests, waterproof flooring, portable heating units x2.'\n"
	$system:=$system+"CRITICAL for 'replace_services' actions: the hiddenPrompt MUST contain two explicit sections:\n"
	$system:=$system+"  Section REMOVE: list exact labels of existing services to remove (copy them verbatim from the event's services list), e.g. 'REMOVE: Poncho pluie jetable (lot de 50) x3, Parapluie personnalisé événement x43'\n"
	$system:=$system+"  Section SEARCH: describe what replacement services to search in the catalog, e.g. 'SEARCH: outdoor lounge furniture for 86 guests, comfort seating'\n"
	$system:=$system+"Respond ONLY with a valid JSON object matching the weather_actions schema. No markdown, no explanation."

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
	$user:=$user+"Return the weather risk analysis with explanation and 2-4 recommended actions covering diverse strategies."

	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	var $evt : cs.EventEntity:=$event
	This._chat:=This._createChat($system; $schemaWeather; "weather_actions"; Formula($self._onWeatherChatDone($1; $cb; $evt)))
	This._chat.prompt($user)

Function _onWeatherChatDone($chatResult : Object; $callback : 4D.Function; $event : cs.EventEntity)
	If (($chatResult#Null) && (Not($chatResult.terminated)))
		return 
	End if 
	var $result : Object:={success: False; weatherActions: Null; validationError: ""; validation: Null}
	var $parsed : Object:=This._extractParsedResponse($chatResult)
	If ($parsed=Null)
		$result.validationError:="schema_weather_actions: "+This._extractError($chatResult)
		$callback.call(Null; $result)
		return 
	End if 
	// Inject eventID si manquant (le LLM oublie parfois ce champ)
	If (($parsed.eventID=Null) || ($parsed.eventID=""))
		$parsed.eventID:=$event.ID
	End if 
	// JSON Validate on the 4D side — post-AI safety net (blog pattern)
	$result.validation:=This._validateResponse($parsed; "schema_weather_actions.json")
	If (Not($result.validation.success))
		$result.validationError:="schema_weather_actions: "+JSON Stringify($result.validation.errors)
		$callback.call(Null; $result)
		return 
	End if 
	$result.success:=True
	$result.weatherActions:=$parsed
	$callback.call(Null; $result)

// ─── Scenario 3: Client modification email linked to a known event ──────────
// The event is already identified — no need to disambiguate.
// $callback receives {success; impacts; validationError}
Function analyzeLinkedEmailAsync($email : cs.EmailEntity; $event : cs.EventEntity; $eventLines : Collection; $callback : 4D.Function)
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
	var $line : Object
	For each ($line; $eventLines)
		$linesText:=$linesText+"- [ID:"+String($line.serviceID)+"] "+$line.serviceLabel+" × "+String($line.quantity)+" @ "+String($line.unitPrice)+"€/u\n"
	End for each 

	var $system : Text:="You are a contract specialist for Event Pulse. "
	$system:=$system+"A client has sent a modification request for a confirmed event. The event is already identified. "
	$system:=$system+"Analyze the request and propose exactly ONE executionAction (actionType='calculate_impact'). "
	$system:=$system+"In the hiddenPrompt, describe precisely: which services to REMOVE (use exact labels from the existing services list) "
	$system:=$system+"and which services to SEARCH for and ADD (only if they could plausibly exist in a standard event catalog). "
	$system:=$system+"If the requested substitute service is unlikely to be in a standard catalog, propose only the removal. "
	$system:=$system+"Set selectedEventID to the event ID provided. Do not populate candidateEvents.\n"
	$system:=$system+"Respond ONLY with a valid JSON object matching the modification_impacts schema. No markdown."

	var $user : Text:="From: "+$email.sender+" <"+$email.senderEmail+">"
	$user:=$user+"\nSubject: "+$email.subject+"\n\n"
	$user:=$user+"Body:\n"+$email.body+"\n\n"
	$user:=$user+"Event: "+$eventText+"\n"
	If ($eventLines.length>0)
		$user:=$user+"\nCurrent services:\n"+$linesText
	End if 

	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	This._chat:=This._createChat($system; $schemaImpacts; "modification_impacts"; Formula($self._onModificationChatDone($1; $cb)))
	This._chat.prompt($user)

Function _onModificationChatDone($chatResult : Object; $callback : 4D.Function)
	If (($chatResult#Null) && (Not($chatResult.terminated)))
		return 
	End if 
	var $result : Object:={success: False; ambiguous: False; impacts: Null; validationError: ""; validation: Null}
	var $parsed : Object:=This._extractParsedResponse($chatResult)
	If ($parsed=Null)
		$result.validationError:="schema_modification_impacts: "+This._extractError($chatResult)
		$callback.call(Null; $result)
		return 
	End if 
	$result.validation:=This._validateResponse($parsed; "schema_modification_impacts.json")
	If (Not($result.validation.success))
		$result.validationError:="schema_modification_impacts: "+JSON Stringify($result.validation.errors)
		$callback.call(Null; $result)
		return 
	End if 
	$result.success:=True
	$result.impacts:=$parsed
	$callback.call(Null; $result)

// ─── generateDraftEmail: confirmation email after applying an action ──────────
// $callback receives {success; emailText; validationError}
Function generateDraftEmailAsync($event : cs.EventEntity; $action : Object; $proposedLines : Collection; $callback : 4D.Function)
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
	If ($action#Null)
		$user:=$user+"Proposed action: "+String($action.label)+"\n"
		If ($action.description#Null)
			$user:=$user+"Details: "+String($action.description)+"\n"
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
Function draftReplyAsync($hiddenPrompt : Text; $email : cs.EmailEntity; $event : cs.EventEntity; $eventLines : Collection; $callback : 4D.Function)
	var $venue : cs.VenueEntity:=$event.venue
	var $eventContext : Text:="Contract: "+$event.contractRef
	$eventContext:=$eventContext+" | Date: "+String($event.eventDate; "yyyy-MM-dd")
	$eventContext:=$eventContext+" | Venue: "+($venue ? $venue.name+", "+$venue.city : "?")
	$eventContext:=$eventContext+" | Guests: "+String($event.guestCount)
	$eventContext:=$eventContext+" | Option: "+$event.venueOption

	var $linesText : Text:=""
	var $line : Object
	For each ($line; $eventLines)
		$linesText:=$linesText+"- "+$line.serviceLabel+" × "+String($line.quantity)+" @ "+String($line.unitPrice)+"€ = "+String($line.quantity*$line.unitPrice)+"€\n"
	End for each 

	var $system : Text:="You are an event coordinator at Event Pulse drafting a professional client reply email. "
	$system:=$system+"Write a clear, professional email in the same language as the client's original email. "
	$system:=$system+"Include the client's first name in the salutation. Be concise and action-oriented. "
	$system:=$system+"Do NOT include subject line or headers — just the email body text."

	var $user : Text:="Original email from client:\n"
	If ($email#Null)
		$user:=$user+"From: "+$email.sender+"\nSubject: "+$email.subject+"\n\n"+$email.body+"\n\n"
	End if 
	$user:=$user+"Event: "+$eventContext+"\n"
	If ($linesText#"")
		$user:=$user+"Current services:\n"+$linesText+"\n"
	End if 
	$user:=$user+"Task: "+$hiddenPrompt

	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	This._chat:=This._createChat($system; Null; ""; Formula($self._onDraftReplyChatDone($1; $cb)))
	This._chat.prompt($user)

Function _onDraftReplyChatDone($chatResult : Object; $callback : 4D.Function)
	If (Not($chatResult.success))
		$callback.call(Null; {success: False; draft: ""; error: This._extractError($chatResult)})
		return 
	End if 
	If ($chatResult.choice=Null)
		$callback.call(Null; {success: False; draft: ""; error: "No content returned by AI"})
		return 
	End if 
	$callback.call(Null; {success: True; draft: $chatResult.choice.message.content; error: ""})

// ─── Re-evaluation of remaining actions after applying an action ────────────────
// $callback receives {success; actions; validationError}
Function reassessActionsAsync($remainingActions : Collection; $appliedLabel : Text; $eventLines : Collection; $callback : 4D.Function)
	var $schemaReassess : Object:=This._loadSchema("schema_reassess_actions.json")
	If ($schemaReassess=Null)
		$callback.call(Null; {success: False; actions: []; validationError: "Cannot load schema_reassess_actions.json"})
		return 
	End if 

	var $servicesSnippet : Text:=""
	var $line : Object
	For each ($line; $eventLines)
		$servicesSnippet:=$servicesSnippet+"- "+$line.serviceLabel+" × "+String($line.quantity)+" @ "+String($line.unitPrice)+"€\n"
	End for each 

	var $actionsSnippet : Text:=""
	var $action : Object
	For each ($action; $remainingActions)
		$actionsSnippet:=$actionsSnippet+"- ["+$action.priority+"] "+$action.label+": "+$action.description+"\n"
	End for each 

	var $system : Text:="You are a risk management specialist for Event Pulse. "
	$system:=$system+"An action has just been applied to an event. Re-evaluate the remaining proposed actions to determine which are still relevant.\n\n"
	$system:=$system+"For each remaining action, decide:\n"
	$system:=$system+"- Keep it if it's still needed given the updated service list\n"
	$system:=$system+"- Drop it if the applied action already resolves what it was targeting\n"
	$system:=$system+"- Adjust its description or priority if the situation has changed\n\n"
	$system:=$system+"NEVER propose passive monitoring actions. Only concrete service operations.\n"
	$system:=$system+"Return ONLY the actions that are still relevant. If all issues are resolved, return an empty actions array.\n"
	$system:=$system+"Respond ONLY with a valid JSON object matching the reassess_actions schema."

	var $user : Text:="Action just applied: "+$appliedLabel+"\n\n"
	$user:=$user+"Current services on event (after applying action):\n"+$servicesSnippet+"\n"
	$user:=$user+"Remaining actions to reassess:\n"+$actionsSnippet+"\n"
	$user:=$user+"Return only the actions that are still necessary."

	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	This._chat:=This._createChat($system; $schemaReassess; "reassess_actions"; Formula($self._onReassessChatDone($1; $cb)))
	This._chat.prompt($user)

Function _onReassessChatDone($chatResult : Object; $callback : 4D.Function)
	If (($chatResult#Null) && (Not($chatResult.terminated)))
		return 
	End if 
	var $result : Object:={success: False; actions: []; validationError: ""}
	var $parsed : Object:=This._extractParsedResponse($chatResult)
	If ($parsed=Null)
		$result.validationError:="schema_reassess_actions: "+This._extractError($chatResult)
		$callback.call(Null; $result)
		return 
	End if 
	$result.validation:=This._validateResponse($parsed; "schema_reassess_actions.json")
	If (Not($result.validation.success))
		$result.validationError:="schema_reassess_actions: "+JSON Stringify($result.validation.errors)
		$callback.call(Null; $result)
		return 
	End if 
	$result.success:=True
	$result.rawAiResponse:=JSON Parse(JSON Stringify($parsed))
	$result.actions:=$parsed.actions
	$callback.call(Null; $result)

// ─── Step 2: Execution with tool calling (ChatHelper + registerTools) ───────────
// $callback receives {success; proposedLines; summary; error}
Function executeActionAsync($hiddenPrompt : Text; $context : Object; $callback : 4D.Function)
	var $system : Text:="You are an event planning execution assistant for Event Pulse. "
	$system:=$system+"You have access to a search_services tool to find services in our catalog. "
	$system:=$system+"Based on the task description, build the list of proposed service changes for this event.\n\n"
	$system:=$system+"The 'delta' field on each line controls what happens:\n"
	$system:=$system+"- 'add': a new service found via search_services to add to the event\n"
	$system:=$system+"- 'remove': an EXISTING service to remove — do NOT search for it, take serviceID and quantity directly from the existing services list in context\n"
	$system:=$system+"- 'update': change the quantity of an existing service\n\n"
	$system:=$system+"For 'replace_services' tasks: you must produce BOTH 'remove' lines (for existing services listed under REMOVE:) AND 'add' lines (found via search_services for items listed under SEARCH:). "
	$system:=$system+"Do NOT search for services that are listed under REMOVE — just emit them with delta:'remove'. "
	$system:=$system+"CRITICAL: Never add a service (delta:'add') if you are also removing a service with the same or equivalent label. A service cannot be both removed and added in the same proposal.\n\n"
	$system:=$system+"Context:\n"
	If ($context.eventID#Null)
		$system:=$system+"- Event ID: "+$context.eventID+"\n"
	End if 
	If ($context.eventDate#Null)
		$system:=$system+"- Event Date: "+$context.eventDate+"\n"
	End if 
	If ($context.guestCount#Null)
		$system:=$system+"- Guest Count: "+String($context.guestCount)+"\n"
	End if 
	If ($context.venueName#Null)
		$system:=$system+"- Venue: "+$context.venueName+"\n"
	End if 
	If (($context.existingLines#Null) && ($context.existingLines.length>0))
		$system:=$system+"\nExisting services on this event:\n"
		var $el : Object
		For each ($el; $context.existingLines)
			$system:=$system+"- [ID:"+String($el.serviceID)+"] "+$el.serviceLabel+" × "+String($el.quantity)+" @ "+String($el.unitPrice)+"€\n"
		End for each 
	End if 
	$system:=$system+"\nFor 'add' lines: ONLY propose services that were actually returned by the search_services tool. "
	$system:=$system+"CRITICAL: If search_services returns no results, return an EMPTY proposedLines array. "
	$system:=$system+"If search_services returns results but none are appropriate, return empty proposedLines AND set summary to explain clearly why each result was rejected (e.g. 'Found: X, Y, Z — rejected because task requires indoor heating and all results are outdoor equipment'). "
	$system:=$system+"NEVER emit 'remove' lines for an 'add_services' task — only emit removes for 'remove_services' or 'replace_services' tasks. "
	$system:=$system+"For 'remove' lines: use the exact serviceID from the existing services list above — do NOT search for them. The serviceID for removes MUST be the [ID:xxx] value from the existing services list. "
	$system:=$system+"Return a JSON with: proposedLines (array of {serviceID, quantity, delta}), summary (text). "
	$system:=$system+"The summary must describe the proposed changes using conditional language (e.g. 'We propose to add...', 'We recommend removing...') — NOT past tense. These changes are proposals pending client approval."
	$system:=$system+"Do NOT include label, category, unitPrice, or totalImpact — those are resolved server-side."

	var $execSchema : Object:=This._loadSchema("schema_action_execution.json")
	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	// Store existing lines so _enrichProposedLines can use actual booked prices for removes
	This._existingLines:=($context.existingLines ? $context.existingLines : [])
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
// For 'remove' lines: use actual booked price from existing event lines (event-specific).
// For 'add' lines: use catalog price from ds.Service.
Function _enrichProposedLines($lines : Collection) : Collection
	If ($lines=Null)
		return []
	End if 
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
				For each ($el; This._existingLines)
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

// ─── Builds the catalog summary for prompts ─────────────────────────────────────
Function _buildCatalogSnippet($catalog : Collection) : Text
	var $result : Text:=""
	If ($catalog=Null)
		return $result
	End if 
	var $i : Integer
	var $svc : Object
	var $max : Integer:=($catalog.length<30) ? $catalog.length : 30
	For ($i; 0; $max-1)
		$svc:=$catalog[$i]
		$result:=$result+($svc.category || "")+" | "+($svc.label || "")+" | "+String($svc.unitPrice)+"€/"+($svc.unit || "unit")+Char(13)
	End for 
	return $result

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

