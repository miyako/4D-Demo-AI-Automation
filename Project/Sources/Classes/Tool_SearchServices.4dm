// Tool_SearchServices.4dm
// AIKit tool for semantic search in the service catalog
// Pattern registerTools Example 3: tools collection + function named like the tool

property tools : Collection
property _contractRef : Text
property _windowID : Integer

Class constructor($contractRef : Text; $windowID : Integer)
	This._contractRef:=$contractRef || ""
	This._windowID:=$windowID || 0
	This.tools:=[{ \
		name: "search_services"; \
		description: "Search the service catalog to find services matching a description. Returns matching services with their ID, label, category, unit price, and unit. Use this to find appropriate services for event quotes, weather contingencies, or modifications."; \
		parameters: { \
			type: "object"; \
			properties: { \
				query: { \
					type: "string"; \
					description: "Natural language description of the service needed, e.g. 'outdoor tent for rain protection' or 'catering service for 200 guests'" \
				}; \
				category: { \
					type: "string"; \
					description: "Optional service category to filter results. ONLY use one of these exact values: Accommodation, Catering, Communication, Coordination, Entertainment, Furniture & Decor, Health & Safety, Lighting, Photography & Film, Security, Sound & AV, Structures, Technical, Transport. Do NOT invent categories." \
				} \
			}; \
			required: ["query"] \
		} \
	}]

Function search_services($params : Object) : Text
	var $matcher : cs.ServiceMatcher:=cs.ServiceMatcher.new()
	var $category : Text:=$params.category || ""
	// Never expose Venue-category services to the AI
	If ($category="Venue")
		$category:=""
	End if 
	// Push query details to form status
	If (This._windowID>0)
		var $statusMsg : Text:="🔍 Searching: "+String($params.query)+(($category#"") ? " | "+$category : "")
		var $w : Integer:=This._windowID
		CALL FORM($w; Formula(Form._setAiStatus($1)); $statusMsg)
	End if 
	var $results : Collection:=$matcher.search($params.query; $category; 5)
	// Strip any Venue-category items that may have slipped through semantic search
	$results:=$results.query("category != :1"; "Venue")

	// Debug log — include returned service labels for diagnosability
	var $labels : Collection:=$results.extract("label")
	var $logEntry : Text:=String(Current time)+" query="+String($params.query)+" category="+$category+" results="+String($results.length)+($results.length>0 ? " ["+$labels.join(", ")+"]" : "")+"\n"
	var $logFile : 4D.File:=Folder(fk logs folder).file("search_services.log")
	$logFile.setText($logFile.exists ? ($logFile.getText()+$logEntry) : $logEntry)
	// Per-event log
	If (This._contractRef#"")
		var $callDetail : Text:="query: "+String($params.query)+(($category#"") ? " | category: "+$category : "")
		cs.EventLogger.me.logBlock(This._contractRef; "AI TOOL"; "search_services — CALL"; $callDetail)
		cs.EventLogger.me.logBlock(This._contractRef; "AI TOOL"; "search_services — RESULT ("+String($results.length)+" items)"; ($results.length>0 ? $labels.join(Char(10)) : "(no results)"))
	End if 

	If ($results.length=0)
		return JSON Stringify({results: []; message: "No matching services found"})
	End if 

	return JSON Stringify({results: $results})
