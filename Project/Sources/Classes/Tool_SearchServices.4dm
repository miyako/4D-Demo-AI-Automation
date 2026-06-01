// Tool_SearchServices.4dm
// Tool AIKit pour la recherche sémantique dans le catalogue de services
// Pattern registerTools Example 3 : tools collection + function nommée comme le tool

property tools : Collection

Class constructor()
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
					description: "Optional service category to filter results, e.g. 'Structures', 'Traiteur', 'Sonorisation'" \
				} \
			}; \
			required: ["query"] \
		} \
	}]

Function search_services($params : Object) : Text
	var $matcher : cs.ServiceMatcher:=cs.ServiceMatcher.new()
	var $category : Text:=Choose($params.category#Null; $params.category; "")
	var $results : Collection:=$matcher.search($params.query; $category; 5)

	// Debug log
	var $logEntry : Text:=String(Current time)+" query="+String($params.query)+" category="+$category+" results="+String($results.length)+"\n"
	var $logFile : 4D.File:=Folder(fk logs folder).file("search_services.log")
	$logFile.setText($logFile.exists ? ($logFile.getText()+$logEntry) : $logEntry)

	If ($results.length=0)
		return JSON Stringify({results: []; message: "No matching services found"})
	End if 

	return JSON Stringify({results: $results})
