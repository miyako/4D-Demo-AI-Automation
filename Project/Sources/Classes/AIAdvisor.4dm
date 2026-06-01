// AIAdvisor.4dm
// Appel OpenAI via AIKit Chat Helper + JSON Validate (Draft 2020-12)
// Utilise le Chat Helper pour la gestion automatique de l'historique et des tools
// Toutes les méthodes publiques sont async (non-bloquantes via parameters.formula)
// Provider et modèle configurés dans AIProviders.json (model alias "chat")

property _client : Object
property _model : Text
property _chat : cs.AIKit.OpenAIChatHelper

Class constructor()
	This._model:="chat"  // model alias défini dans AIProviders.json
	This._client:=cs.AIKit.OpenAI.new()

// ─── Factory : crée un Chat Helper configuré ─────────────────────────────────
// Les options sont passées à chat.create() pour initialisation correcte
Function _createChat($systemPrompt : Text; $schema : Object; $schemaName : Text; $formula : 4D.Function) : cs.AIKit.OpenAIChatHelper
	var $options:=cs.AIKit.OpenAIChatCompletionsParameters.new()
	$options.model:=This._model
	$options.temperature:=0.2
	$options.max_completion_tokens:=2048
	$options.formula:=$formula
	$options.response_format:={type: "json_schema"; json_schema: { \
		name: $schemaName; \
		schema: $schema; \
		strict: True \
	}}
	return This._client.chat.create($systemPrompt; $options)

// ═══════════════════════════════════════════════════════════════════════════════
// ─── ASYNC API (Chat Helper + formula) ────────────────────────────────────────
// Toutes les méthodes retournent immédiatement.
// Le callback (4D.Function) est invoqué dans la boucle événement du formulaire.
// Pattern: $self:=This + Formula($self._onXxx($1; captured_params...))
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Scénario 1 : Analyse email = demande de devis ───────────────────────────
// $callback reçoit {success; extraction; actions; validationError}
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
	var $result : Object:={success: False; extraction: Null; actions: Null; validationError: ""}
	var $parsed : Object:=This._extractParsedResponse($chatResult)
	If ($parsed=Null)
		$result.validationError:=This._extractError($chatResult)
		$callback.call(Null; $result)
		return 
	End if 
	$result.success:=True
	$result.extraction:=$parsed.extraction
	$result.actions:=$parsed.actions
	$callback.call(Null; $result)

// ─── Scénario 2 : Alerte météo sur un événement ──────────────────────────────
// $callback reçoit {success; weatherActions; validationError}
Function analyzeWeatherRiskAsync($event : cs.EventEntity; $weatherData : Object; $eventLines : Collection; $callback : 4D.Function)
	var $schemaWeather : Object:=This._loadSchema("schema_weather_actions.json")
	If ($schemaWeather=Null)
		$callback.call(Null; {success: False; weatherActions: Null; validationError: "Impossible de charger schema_weather_actions.json"})
		return 
	End if 

	var $servicesSnippet : Text:=""
	var $line : Object
	For each ($line; $eventLines)
		$servicesSnippet:=$servicesSnippet+"- "+$line.serviceLabel+" (qté: "+String($line.quantity)+")\n"
	End for each 

	var $venue : cs.VenueEntity:=$event.venue
	var $venueInfo : Text
	If ($venue#Null)
		$venueInfo:=$venue.name+" - "+$venue.city+", "+$venue.country+" ("+$venue.venueType+")"
		$venueInfo:=$venueInfo+" | Event option: "+$event.venueOption
		// Mention indoor alternative if available
		If (($event.venueOption="outdoor") && ($venue.indoorOption#Null))
			$venueInfo:=$venueInfo+"\nIndoor alternative available at same venue: "+$venue.indoorOption.name+" (capacity: "+String($venue.indoorOption.capacity)+", rental: "+String($venue.indoorOption.rentalPrice)+"€)"
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
	$system:=$system+"7) If the event is outdoor and an indoor alternative is available at the same venue, propose 'switch_venue' as one action\n"
	$system:=$system+"   NEVER propose 'switch_venue' if the event venueOption is already 'indoor'.\n\n"
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

	// Weather setup prévu pour cet événement
	var $setup : Object:=$event.weatherSetup
	If ($setup#Null)
		$user:=$user+"Planned Weather Setup:\n"
		$user:=$user+"- Conditions: "+$setup.conditions+" ("+Choose($setup.conditions="indifferent"; "indoor/weather-independent"; Choose($setup.conditions="sunny"; "planned for fair weather"; "already prepared for rain"))+")\n"
		$user:=$user+"- Temperature: "+$setup.temperature+" ("+Choose($setup.temperature="normal"; "standard setup"; Choose($setup.temperature="cold"; "cold-weather equipment included"; "heat management included"))+")\n\n"
	Else 
		$user:=$user+"Planned Weather Setup: not specified (assume sunny/normal)\n\n"
	End if 

	$user:=$user+"Weather Forecast:\n"
	$user:=$user+JSON Stringify($weatherData)+"\n\n"
	$user:=$user+"Booked Services:\n"+$servicesSnippet+"\n"
	$user:=$user+"Return the weather risk analysis with explanation and 1-4 recommended actions."

	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	var $evt : cs.EventEntity:=$event
	This._chat:=This._createChat($system; $schemaWeather; "weather_actions"; Formula($self._onWeatherChatDone($1; $cb; $evt)))
	This._chat.prompt($user)

Function _onWeatherChatDone($chatResult : Object; $callback : 4D.Function; $event : cs.EventEntity)
	If (($chatResult#Null) && (Not($chatResult.terminated)))
		return 
	End if 
	var $result : Object:={success: False; weatherActions: Null; validationError: ""}
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
	$result.success:=True
	$result.weatherActions:=$parsed
	$callback.call(Null; $result)

// ─── Scénario 3 : Email de modification client ───────────────────────────────
// $callback reçoit {success; ambiguous; impacts; validationError}
Function analyzeModificationEmailAsync($email : cs.EmailEntity; $candidateEvents : Collection; $eventLines : Collection; $callback : 4D.Function)
	var $schemaImpacts : Object:=This._loadSchema("schema_modification_impacts.json")
	If ($schemaImpacts=Null)
		$callback.call(Null; {success: False; ambiguous: False; impacts: Null; validationError: "Impossible de charger schema_modification_impacts.json"})
		return 
	End if 

	var $candidatesText : Text:=""
	var $c : Object
	For each ($c; $candidateEvents)
		$candidatesText:=$candidatesText+"- ID: "+$c.eventID+" | "+$c.contractRef+" | "+$c.eventDate+" | "+$c.venueName+" | "+String($c.guestCount)+" guests\n"
	End for each 

	var $linesText : Text:=""
	var $line : Object
	For each ($line; $eventLines)
		$linesText:=$linesText+"- "+$line.serviceLabel+" × "+String($line.quantity)+" @ "+String($line.unitPrice)+"€/u\n"
	End for each 

	var $system : Text:="You are a contract specialist for Event Pulse. "
	$system:=$system+"A client has sent a modification request. Your job is to:\n"
	$system:=$system+"1) Identify which event they refer to (may be ambiguous)\n"
	$system:=$system+"2) List all impacts (services added/removed, cost changes, etc.)\n"
	$system:=$system+"3) Determine if an amendment ('avenant') is needed\n"
	$system:=$system+"4) Propose executionActions: concrete actions the user can click to apply changes\n\n"
	$system:=$system+"For each executionAction, include a 'hiddenPrompt' describing exactly what services to search/add/remove/update with quantities and constraints.\n"
	$system:=$system+"Respond ONLY with a valid JSON object matching the modification_impacts schema. No markdown."

	var $user : Text:="Client email subject: "+$email.subject+"\n"
	$user:=$user+"From: "+$email.sender+"\n\n"
	$user:=$user+"Body:\n"+$email.body+"\n\n"
	$user:=$user+"Candidate events for this client:\n"+$candidatesText+"\n"
	If ($eventLines.length>0)
		$user:=$user+"Current services on most likely event:\n"+$linesText+"\n"
	End if 
	$user:=$user+"If multiple events could match, populate 'candidateEvents' and leave 'impacts' minimal. "
	$user:=$user+"Otherwise populate 'impacts' fully."

	var $self : Object:=This
	var $cb : 4D.Function:=$callback
	This._chat:=This._createChat($system; $schemaImpacts; "modification_impacts"; Formula($self._onModificationChatDone($1; $cb)))
	This._chat.prompt($user)

Function _onModificationChatDone($chatResult : Object; $callback : 4D.Function)
	If (($chatResult#Null) && (Not($chatResult.terminated)))
		return 
	End if 
	var $result : Object:={success: False; ambiguous: False; impacts: Null; validationError: ""}
	var $parsed : Object:=This._extractParsedResponse($chatResult)
	If ($parsed=Null)
		$result.validationError:="schema_modification_impacts: "+This._extractError($chatResult)
		$callback.call(Null; $result)
		return 
	End if 
	$result.success:=True
	$result.impacts:=$parsed
	$result.ambiguous:=($parsed.candidateEvents#Null) && ($parsed.candidateEvents.length>1)
	$callback.call(Null; $result)

// ─── Temps 2 : Exécution avec tool calling (ChatHelper + registerTools) ──────
// $callback reçoit {success; proposedLines; summary; totalImpact; error}
Function executeActionAsync($hiddenPrompt : Text; $context : Object; $callback : 4D.Function)
	var $system : Text:="You are an event planning execution assistant for Event Pulse. "
	$system:=$system+"You have access to a search_services tool to find services in our catalog. "
	$system:=$system+"Based on the task description, build the list of proposed service changes for this event.\n\n"
	$system:=$system+"The 'delta' field on each line controls what happens:\n"
	$system:=$system+"- 'add': a new service found via search_services to add to the event\n"
	$system:=$system+"- 'remove': an EXISTING service to remove — do NOT search for it, take label/quantity/unitPrice directly from the existing services list in context\n"
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
			$system:=$system+"- "+$el.serviceLabel+" × "+String($el.quantity)+" @ "+String($el.unitPrice)+"€\n"
		End for each 
	End if 
	$system:=$system+"\nFor 'add' lines: ONLY propose services that were actually returned by the search_services tool. "
	$system:=$system+"CRITICAL: If search_services returns no results for the requested service, return an EMPTY proposedLines array. "
	$system:=$system+"NEVER emit 'remove' lines for an 'add_services' task — only emit removes for 'remove_services' or 'replace_services' tasks. "
	$system:=$system+"For 'remove' lines: use the exact label and unitPrice from the existing services list above — do NOT search for them. "
	$system:=$system+"Return a JSON with: proposedLines (array of {serviceID, label, category, quantity, unitPrice, delta}), summary (text), totalImpact (number in euros). "
	$system:=$system+"For 'remove' lines, serviceID may be empty string. totalImpact = sum of add lines minus sum of remove lines."

	var $execSchema : Object:=This._loadSchema("schema_action_execution.json")
	var $self : Object:=This
	var $cb : 4D.Function:=$callback
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
	var $result : Object:={success: False; proposedLines: Null; summary: ""; totalImpact: 0; error: ""}
	var $parsed : Object:=This._extractParsedResponse($chatResult)
	If ($parsed=Null)
		$result.error:=This._extractError($chatResult)
		$callback.call(Null; $result)
		return 
	End if 
	$result.success:=True
	$result.proposedLines:=$parsed.proposedLines
	$result.summary:=$parsed.summary
	$result.totalImpact:=$parsed.totalImpact
	$callback.call(Null; $result)

// ═══════════════════════════════════════════════════════════════════════════════
// ─── HELPERS ──────────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Extrait et parse le JSON de la réponse chat ─────────────────────────────
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

// ─── Extrait un message d'erreur lisible de la réponse chat ──────────────────
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

// ─── Construction du résumé catalogue pour les prompts ───────────────────────
Function _buildCatalogSnippet($catalog : Collection) : Text
	var $result : Text:=""
	If ($catalog=Null)
		return $result
	End if 
	var $i : Integer
	var $svc : Object
	var $max : Integer:=Choose($catalog.length<30; $catalog.length; 30)
	For ($i; 0; $max-1)
		$svc:=$catalog[$i]
		$result:=$result+Choose($svc.category#Null; $svc.category; "")+" | "+Choose($svc.label#Null; $svc.label; "")+" | "+String($svc.unitPrice)+"€/"+Choose($svc.unit#Null; $svc.unit; "unit")+Char(13)
	End for 
	return $result

// ─── Chargement de schéma depuis Resources/schemas ───────────────────────────
Function _loadSchema($filename : Text) : Object
	var $file : 4D.File:=Folder(fk resources folder).file("schemas/"+$filename)
	If (Not($file.exists))
		return Null
	End if 
	return JSON Parse($file.getText())

