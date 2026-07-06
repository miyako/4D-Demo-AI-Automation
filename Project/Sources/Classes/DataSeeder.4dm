// DataSeeder.4dm
// Seeds the database with JSON data if it is empty
// Called at application startup (On Startup / Home form On Load)

property _weatherTemplates : Object

singleton Class constructor()
	
	// ─── Main entry point ───────────────────────────────────────────────────────────
Function seedIfEmpty()
	If (ds.Client.all().length=0)
		This._seedClients()
	End if 
	If (ds.Venue.all().length=0)
		This._seedVenues()
	End if 
	If (ds.Service.all().length=0)
		This._seedServices()
	End if 
	If (ds.Event.all().length=0)
		This._seedEventsAndLines()
	End if 
	If (ds.Email.all().length=0)
		This._seedEmails()
	End if 
	
	// Generate vector embeddings for services (if missing)
	This._buildServiceEmbeddings()
	
	// ─── Full reset: empties everything and re-imports ──────────────────────────────
Function resetAll()
	// Delete in order (children first)
	ds.EventLine.all().drop()
	ds.Event.all().drop()
	ds.Email.all().drop()
	ds.Service.all().drop()
	ds.Venue.all().drop()
	ds.Client.all().drop()
	
	// Reset cached templates so file is reloaded
	This._weatherTemplates:=Null
	
	// Re-import everything from JSON files
	This._seedClients()
	This._seedVenues()
	This._seedServices()
	This._seedEventsAndLines()
	This._seedEmails()
	
	// Recalculate embeddings (forced because services are new)
	This._buildServiceEmbeddings()
	
	// Clear event logs
	var $logsFolder : 4D.Folder:=Folder(fk logs folder)
	If ($logsFolder.exists)
		var $logFile : 4D.File
		For each ($logFile; $logsFolder.files())
			$logFile.delete()
		End for each 
	End if 
	
	// ─── Clear only: empties everything without re-importing ────────────────────────
Function clearAll()
	ds.EventLine.all().drop()
	ds.Event.all().drop()
	ds.Email.all().drop()
	ds.Service.all().drop()
	ds.Venue.all().drop()
	ds.Client.all().drop()
	This._weatherTemplates:=Null
	
	// ─── Clients ─────────────────────────────────────────────────────────────────────
Function _seedClients()
	var $file : 4D.File:=Folder(fk resources folder).file("data/clients.json")
	var $data : Collection:=JSON Parse($file.getText())
	var $item : Object
	var $e : cs.ClientEntity
	For each ($item; $data)
		$e:=ds.Client.new()
		$e.companyName:=$item.companyName
		$e.contactName:=$item.contactName
		$e.email:=$item.email
		$e.phone:=$item.phone
		$e.country:=$item.country
		$e.seedIndex:=$item.seedIndex
		$e.save()
	End for each 
	
	// ─── Venues ──────────────────────────────────────────────────────────────────────
Function _seedVenues()
	//var $file : 4D.File:=Folder(fk resources folder).file("data/venues.json")
	var $file : 4D.File:=Folder(fk resources folder).file("data/venues.ja.json")
	
	var $data : Collection:=JSON Parse($file.getText())
	var $item : Object
	var $e : cs.VenueEntity
	For each ($item; $data)
		$e:=ds.Venue.new()
		$e.name:=$item.name
		$e.address:=$item.address
		$e.city:=$item.city
		$e.country:=$item.country
		$e.latitude:=$item.latitude
		$e.longitude:=$item.longitude
		$e.venueType:=$item.venueType
		$e.capacity:=$item.capacity
		$e.timezone:=$item.timezone
		$e.seedIndex:=$item.seedIndex
		If ($item.indoorOption#Null)
			$e.indoorOption:=$item.indoorOption
		End if 
		If ($item.outdoorOption#Null)
			$e.outdoorOption:=$item.outdoorOption
		End if 
		$e.save()
	End for each 
	
	// ─── Services ────────────────────────────────────────────────────────────────────
Function _seedServices()
	//var $file : 4D.File:=Folder(fk resources folder).file("data/services.json")
	var $file : 4D.File:=Folder(fk resources folder).file("data/services.ja.json")
	var $data : Collection:=JSON Parse($file.getText())
	var $item : Object
	var $e : cs.ServiceEntity
	For each ($item; $data)
		$e:=ds.Service.new()
		$e.category:=$item.category
		$e.label:=$item.label
		$e.unit:=$item.unit
		$e.unitPrice:=$item.unitPrice
		$e.available:=$item.available
		$e.description:=$item.description
		$e.seedIndex:=$item.seedIndex
		$e.save()
	End for each 
	
	// ─── Events + EventLines ────────────────────────────────────────────────────────
Function _seedEventsAndLines()
	// Delegates to regenerateEvents() which loads events.json with relative dates
	This.regenerateEvents()
	
	// ─── Generates realistic lines for an event ────────────────────────────────────
Function _generateEventLines($evt : cs.EventEntity; $item : Object; $svcByCategory : Object)
	var $guestCount : Integer:=$item.guestCount
	var $status : Text:=$item.status
	var $lineStatus : Text:=$status="confirmed" ? "confirmed" : "pending"
	
	// Build weather profile key
	var $setup : Object:=$evt.weatherSetup
	var $conditions : Text:=$setup ? $setup.conditions : "indifferent"
	var $temperature : Text:=$setup ? $setup.temperature : "normal"
	var $venueOption : Text:=$evt.venueOption
	var $profileKey : Text:=$venueOption+"__"+$conditions+"__"+$temperature
	
	// Load templates (cached)
	If (This._weatherTemplates=Null)
		var $tplFile : 4D.File:=Folder(fk resources folder).file("data/weather-service-templates.json")
		This._weatherTemplates:=JSON Parse($tplFile.getText())
	End if 
	
	// Fallback to indoor__indifferent__normal if key not found
	var $tpl : Object:=This._weatherTemplates[$profileKey]
	If ($tpl=Null)
		$tpl:=This._weatherTemplates["indoor__indifferent__normal"]
	End if 
	If ($tpl=Null)
		return 
	End if 
	
	// Apply mandatory services
	var $spec : Object
	For each ($spec; $tpl.mandatory)
		var $qty : Integer
		If ($spec.useGuests=True)
			$qty:=$guestCount
		Else 
			If ($spec.useGuestsFraction#Null)
				$qty:=Int($guestCount/$spec.useGuestsFraction)
				If ($spec.minQty#Null)
					If ($qty<$spec.minQty)
						$qty:=$spec.minQty
					End if 
				End if 
				If ($qty<1)
					$qty:=1
				End if 
			Else 
				$qty:=$spec.qty
			End if 
		End if 
		If ($spec.label#Null)
			This._addServiceByLabel($evt; $svcByCategory; $spec.category; $spec.label; $qty; $lineStatus)
		Else 
			If ($spec.prefer="outdoor")
				This._addPreferredService($evt; $svcByCategory; $spec.category; $qty; $lineStatus; True)
			Else 
				If ($spec.prefer="indoor")
					This._addPreferredService($evt; $svcByCategory; $spec.category; $qty; $lineStatus; False)
				Else 
					This._addRandomService($evt; $svcByCategory; $spec.category; $qty; $lineStatus)
				End if 
			End if 
		End if 
	End for each 
	
	// Apply optional services (probabilistic)
	For each ($spec; $tpl.optional)
		var $roll : Real:=Random%100/100
		If ($roll<$spec.prob)
			var $oqty : Integer
			If ($spec.useGuestsFraction#Null)
				$oqty:=Int($guestCount/$spec.useGuestsFraction)
				If ($oqty<1)
					$oqty:=1
				End if 
			Else 
				$oqty:=$spec.qty
			End if 
			If ($spec.label#Null)
				This._addServiceByLabel($evt; $svcByCategory; $spec.category; $spec.label; $oqty; $lineStatus)
			Else 
				This._addRandomService($evt; $svcByCategory; $spec.category; $oqty; $lineStatus)
			End if 
		End if 
	End for each 
	
	// Apply forced services (override randomness for events with email references)
	If ($item.forcedServices#Null)
		var $forced : Object
		For each ($forced; $item.forcedServices)
			This._addServiceByLabel($evt; $svcByCategory; $forced.category; $forced.label; Num($forced.qty); $lineStatus)
		End for each 
	End if 
	
	// Add venue rental as a service line (price from venue option, not catalog)
	var $rentalLabel : Text:=$venueOption="indoor" ? "Indoor venue rental" : "Outdoor venue rental"
	var $rentalPrice : Real:=Num($item.venueRentalPrice)
	var $venueRentalList : Collection:=$svcByCategory["Venue"]
	If (($rentalPrice>0) && ($venueRentalList#Null))
		var $rsvc : Object:=$venueRentalList.query("label = :1"; $rentalLabel).first()
		If ($rsvc#Null)
			This._addLineWithPrice($evt; $rsvc; 1; $lineStatus; $rentalPrice)
		End if 
	End if 
	
	// ─── Adds a random service from a given category ───────────────────────────────
Function _addRandomService($evt : cs.EventEntity; $svcByCategory : Object; $category : Text; $qty : Integer; $lineStatus : Text)
	var $list : Collection:=$svcByCategory[$category]
	If (($list#Null) && ($list.length>0))
		This._addLine($evt; $list[Random%$list.length]; $qty; $lineStatus)
	End if 
	
	// ─── Adds a service preferring outdoor or indoor labels ────────────────────────
Function _addPreferredService($evt : cs.EventEntity; $svcByCategory : Object; $category : Text; $qty : Integer; $lineStatus : Text; $preferOutdoor : Boolean)
	var $list : Collection:=$svcByCategory[$category]
	If (($list=Null) || ($list.length=0))
		return 
	End if 
	var $keyword : Text:=$preferOutdoor ? "extérieure" : "salle"
	var $preferred : Collection:=$list.query("label = :1"; "@"+$keyword+"@")
	If ($preferred.length=0)
		$preferred:=$list
	End if 
	This._addLine($evt; $preferred[Random%$preferred.length]; $qty; $lineStatus)
	
	// ─── Adds a specific service by its label ──────────────────────────────────────
Function _addServiceByLabel($evt : cs.EventEntity; $svcByCategory : Object; $category : Text; $label : Text; $qty : Integer; $lineStatus : Text)
	var $list : Collection:=$svcByCategory[$category]
	If (($list=Null) || ($list.length=0))
		return 
	End if 
	var $svc : Object:=$list.query("label = :1"; $label).first()
	If ($svc#Null)
		If ($qty>0)
			This._addLine($evt; $svc; $qty; $lineStatus)
		End if 
	End if 
	
	// ─── Adds an order line ─────────────────────────────────────────────────────────
Function _addLine($evt : cs.EventEntity; $svc : Object; $qty : Integer; $status : Text)
	This._addLineWithPrice($evt; $svc; $qty; $status; $svc.unitPrice)
	
Function _addLineWithPrice($evt : cs.EventEntity; $svc : Object; $qty : Integer; $status : Text; $price : Real)
	var $line : cs.EventLineEntity:=ds.EventLine.new()
	$line.eventID:=$evt.ID
	$line.serviceID:=$svc.id
	$line.quantity:=$qty
	$line.unitPrice:=$price
	$line.lineStatus:=$status
	$line.save()
	
	// ─── Emails ───────────────────────────────────────────────────────────────────
	// Only modification emails, all linked to a specific confirmed event
Function _seedEmails()
	// Always clear first to stay idempotent prevents duplicates if called multiple times
	ds.Email.all().drop()
	
	//var $file : 4D.File:=Folder(fk resources folder).file("data/emails.json")
	var $file : 4D.File:=Folder(fk resources folder).file("data/emails.ja.json")
	var $data : Collection:=JSON Parse($file.getText())
	var $item : Object
	var $e : cs.EmailEntity
	
	For each ($item; $data)
		$e:=ds.Email.new()
		$e.sender:=$item.sender
		$e.senderEmail:=$item.senderEmail
		$e.subject:=$item.subject
		$e.body:=$item.body
		$e.receivedAt:=Date($item.receivedAt)
		$e.emailStatus:="pending"
		$e.emailType:="modification"
		// Resolve linkedEventIndex → actual event by seedIndex lookup
		var $linkedEvt : cs.EventEntity:=ds.Event.query("seedIndex = :1"; Num($item.linkedEventIndex)).first()
		If ($linkedEvt#Null)
			$e.linkedEventID:=String($linkedEvt.ID)
		Else 
			$e.linkedEventID:=""
		End if 
		$e.save()
	End for each 
	
	// ─── Regeneration of events with relative dates ────────────────────────────────
	// Deletes all events + eventlines, then reloads events.json with
	// dates calculated relative to the current date.
	// Only 1-2 nearby events receive a fake weather alert.
Function regenerateEvents()
	// Delete existing data
	ds.EventLine.all().drop()
	ds.Event.all().drop()
	
	// Load templates from events.json
	//var $file : 4D.File:=Folder(fk resources folder).file("data/events.json")
	var $file : 4D.File:=Folder(fk resources folder).file("data/events.ja.json")
	var $templates : Collection:=JSON Parse($file.getText())
	var $total : Integer:=$templates.length
	
	// Load references from database no ordering needed, lookup by seedIndex
	var $services : cs.ServiceSelection:=ds.Service.all()
	
	// Cache services by category
	var $svcByCategory : Object:={}
	var $svc : cs.ServiceEntity
	var $cat : Text
	For each ($svc; $services)
		$cat:=$svc.category
		If ($svcByCategory[$cat]=Null)
			$svcByCategory[$cat]:=[]
		End if 
		$svcByCategory[$cat].push({id: $svc.ID; label: $svc.label; unitPrice: $svc.unitPrice})
	End for each 
	
	var $today : Date:=Current date
	
	// ── Relative date distribution ─────────────────────────────────────────────
	// 300 events distributed:
	//   [0..39]     → completed  (-1 to -180d)
	//   [40..49]    → cancelled  (-1 to -90d)
	//   [50..119]   → confirmed  (+1 to +30d)   ← demo / weather sweet spot
	//   [120..219]  → confirmed  (+31 to +180d)
	//   [220..279]  → quote      (+5 to +150d)
	//   [280..299]  → confirmed  (+181 to +365d)
	var $i : Integer
	var $item : Object
	var $evt : cs.EventEntity
	var $clientEnt : cs.ClientEntity
	var $venueEnt : cs.VenueEntity
	var $daysOffset : Integer
	var $status : Text
	
	For ($i; 0; $total-1)
		$item:=$templates[$i]
		
		// Determine status and relative date based on slot
		Case of 
			: ($i<40)
				$status:="completed"
				$daysOffset:=-(Random%180+1)
			: ($i<50)
				$status:="cancelled"
				$daysOffset:=-(Random%90+1)
			: ($i<120)
				$status:="confirmed"
				$daysOffset:=(Random%30+1)
			: ($i<220)
				$status:="confirmed"
				$daysOffset:=(Random%150+31)
			: ($i<280)
				$status:="quote"
				$daysOffset:=(Random%150+5)
			Else 
				$status:="confirmed"
				$daysOffset:=(Random%185+181)
		End case 
		
		// Resolve client & venue by seedIndex
		$clientEnt:=ds.Client.query("seedIndex = :1"; $item.clientSeedIndex).first()
		$venueEnt:=ds.Venue.query("seedIndex = :1"; $item.venueSeedIndex).first()
		
		$evt:=ds.Event.new()
		$evt.clientID:=$clientEnt.ID
		$evt.venueID:=$venueEnt.ID
		$evt.eventDate:=$today+$daysOffset
		$evt.status:=$status
		$evt.guestCount:=$item.guestCount
		$evt.contractRef:="CTR-"+String(Year of($today+$daysOffset))+"-"+String(100+$i)
		$evt.notes:=$item.notes
		$evt.createdAt:=Current date
		
		// Determine venue option (indoor/outdoor) based on venue capabilities
		var $venueOption : Text
		If ($venueEnt.venueType="indoor")
			$venueOption:="indoor"
		Else 
			If ($venueEnt.venueType="outdoor")
				$venueOption:="outdoor"
			Else 
				// Mixed: 50/50
				$venueOption:=(Random%2=0) ? "indoor" : "outdoor"
			End if 
		End if 
		$evt.venueOption:=$venueOption
		
		// Compute rental price from venue option (stored for reference, line added in _generateEventLines)
		var $venueRentalPrice : Real
		If ($venueOption="indoor")
			If ($venueEnt.indoorOption#Null)
				$venueRentalPrice:=Num($venueEnt.indoorOption.rentalPrice)
			Else 
				$venueRentalPrice:=2000
			End if 
		Else 
			If ($venueEnt.outdoorOption#Null)
				$venueRentalPrice:=Num($venueEnt.outdoorOption.rentalPrice)
			Else 
				$venueRentalPrice:=1500
			End if 
		End if 
		$evt.venueRentalPrice:=$venueRentalPrice  // keep field as reference for venue switch
		
		// Assign the weatherSetup based on the chosen type
		$evt.weatherSetup:=This._assignWeatherSetup($venueOption)
		
		// Weather alerts will be calculated by the WeatherService
		$evt.weatherAlertLevel:="none"
		$evt.seedIndex:=$item.seedIndex
		$evt.weatherForecast:=Null  // explicit NULL avoids empty-string Object field on catalog migration
		$evt.weatherAlertJson:=Null
		
		$evt.save()
		
		// Generate event lines (pass forcedServices + venueRentalPrice for venue rental line)
		var $fakeItem : Object:={guestCount: $evt.guestCount; status: $status; forcedServices: $item.forcedServices; venueRentalPrice: $venueRentalPrice}
		This._generateEventLines($evt; $fakeItem; $svcByCategory)
	End for 
	
	// Re-seed emails so linkedEventID references match the new event UUIDs
	ds.Email.all().drop()
	This._seedEmails()
	
	// ─── Vector embeddings for services ────────────────────────────────────────────
Function _buildServiceEmbeddings()
	// Check if at least one service has no embedding
	var $missing : cs.ServiceSelection:=ds.Service.query("embedding = null")
	If ($missing.length=0)
		return 
	End if 
	var $matcher : cs.ServiceMatcher:=cs.ServiceMatcher.new()
	$matcher.buildEmbeddings()
	
	// ─── Forces rebuild of all embeddings (after label changes) ────────────────────
Function rebuildEmbeddings()
	var $matcher : cs.ServiceMatcher:=cs.ServiceMatcher.new()
	$matcher.rebuildAllEmbeddings()
	
	// ─── Assignment of weatherSetup based on indoor/outdoor choice ─────────────────
Function _assignWeatherSetup($venueOption : Text) : Object
	var $conditions : Text
	var $temperature : Text
	var $r : Integer:=Random%10
	
	Case of 
		: ($venueOption="indoor")
			// Indoor: weather-indifferent
			$conditions:="indifferent"
			$temperature:="normal"
		Else 
			// Outdoor: mainly fair weather
			$conditions:=$r<7 ? "sunny" : "rain"
			$temperature:=$r<3 ? "hot" : ($r<8 ? "normal" : "cold")
	End case 
	
	return {conditions: $conditions; temperature: $temperature}
	