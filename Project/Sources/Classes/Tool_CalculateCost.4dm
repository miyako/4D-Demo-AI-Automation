// Tool_CalculateCost.4dm
// AIKit tool — computes exact total cost for a list of service IDs + quantities.
// Prevents AI arithmetic errors when verifying removed/added service budgets.

property tools : Collection
property _contractRef : Text

Class constructor($contractRef : Text)
	This._contractRef:=$contractRef || ""
	This.tools:=[{ \
		name: "calculate_cost"; \
		description: "Calculate the exact total cost for a list of services with quantities. Use this to verify the cost of services you plan to add or remove, instead of doing manual arithmetic."; \
		parameters: { \
			type: "object"; \
			properties: { \
				lines: { \
					type: "array"; \
					description: "List of service lines to cost"; \
					items: { \
						type: "object"; \
						properties: { \
							serviceID: {type: "string"; description: "Service UUID"}; \
							quantity: {type: "number"; description: "Quantity"} \
						}; \
						required: ["serviceID"; "quantity"] \
					} \
				} \
			}; \
			required: ["lines"] \
		} \
	}]

Function calculate_cost($params : Object) : Text
	var $lines : Collection:=$params.lines
	If (($lines=Null) || ($lines.length=0))
		return JSON Stringify({total: 0; breakdown: []})
	End if 

	var $breakdown : Collection:=[]
	var $total : Real:=0
	var $line : Object

	For each ($line; $lines)
		var $svc : cs.ServiceEntity:=ds.Service.query("ID = :1"; String($line.serviceID)).first()
		If ($svc#Null)
			var $qty : Integer:=Num($line.quantity)
			var $lineTotal : Real:=$svc.unitPrice * $qty
			$total:=$total+$lineTotal
			$breakdown.push({serviceID: $line.serviceID; label: $svc.label; unitPrice: $svc.unitPrice; quantity: $qty; lineTotal: $lineTotal})
		End if 
	End for each 

	// Per-event log
	If (This._contractRef#"")
		var $detail : Text:="total: "+String($total)+"€ for "+String($breakdown.length)+" lines"
		cs.EventLogger.me.logBlock(This._contractRef; "AI TOOL"; "calculate_cost — RESULT"; $detail)
	End if 

	return JSON Stringify({total: $total; breakdown: $breakdown})
