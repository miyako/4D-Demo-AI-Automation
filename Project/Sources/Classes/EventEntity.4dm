// EventEntity.4dm — Computed attributes for the Event entity
// Used by the EventList entity-selection listbox and EventDetail display

Class extends Entity

// ─── Display helpers ─────────────────────────────────────────────────────────

Function get eventDateStr() : Text
	return String(This.eventDate; "dd/MM/yyyy")

Function get clientName() : Text
	var $c : cs.ClientEntity:=This.client
	return $c ? $c.companyName : "—"

Function get venueName() : Text
	var $v : cs.VenueEntity:=This.venue
	return $v ? $v.name : "—"

Function get venueCity() : Text
	var $v : cs.VenueEntity:=This.venue
	return $v ? $v.city : "—"

Function get guestCountStr() : Text
	return String(This.guestCount)

Function get guestCountLabel() : Text
	return String(This.guestCount)+" guests"

Function get eventDateLong() : Text
	return String(This.eventDate; "EEEE dd MMMM yyyy")

Function get contactInfo() : Text
	var $c : cs.ClientEntity:=This.client
	return $c ? $c.contactName+" · "+$c.email : ""

Function get venueLabel() : Text
	var $v : cs.VenueEntity:=This.venue
	return $v ? $v.name+" – "+$v.city+", "+$v.country : "—"

// ─── Status labels ────────────────────────────────────────────────────────────

// Short badge for listbox column
Function get statusBadge() : Text
	Case of 
		: (This.status="confirmed")
			return "Confirmed"
		: (This.status="quote")
			return "Quote"
		: (This.status="completed")
			return "Done"
		: (This.status="cancelled")
			return "Cancelled"
		Else 
			return This.status
	End case 

// Full label with icon for detail header
Function get statusLabel() : Text
	Case of 
		: (This.status="confirmed")
			return "✅ Confirmed"
		: (This.status="quote")
			return "💬 Quote"
		: (This.status="completed")
			return "✔ Completed"
		: (This.status="cancelled")
			return "❌ Cancelled"
		Else 
			return This.status
	End case 

// ─── Weather icons & alert label ─────────────────────────────────────────────

Function get weatherIcon() : Text
	Case of 
		: (This.weatherAlertLevel="critical")
			return "🚨"
		: (This.weatherAlertLevel="warning")
			return "⛈"
		: (This.weatherAlertLevel="watch")
			return "🌧"
		Else 
			return ""
	End case 

Function get riskLabel() : Text
	Case of 
		: (This.weatherAlertLevel="critical")
			return "🚨 Critical risk – action required"
		: (This.weatherAlertLevel="warning")
			return "⛈ Weather warning for event day"
		: (This.weatherAlertLevel="watch")
			return "🌧 Weather watch – monitor closely"
		Else 
			return "☀ No significant weather risk"
	End case 

// venueOption is a real field ("indoor"/"outdoor") — use venueOptionIcon for the emoji column
Function get venueOptionIcon() : Text
	return This.venueOption="indoor" ? "🏢" : "🌳"

Function get emailIcon() : Text
	If (ds.Email.query("emailStatus = :1 AND linkedEvent.ID = :2"; "pending"; This.ID).length>0)
		return "📧"
	End if 
	return ""

Function get pendingEmail() : cs.EmailEntity
	return ds.Email.query("emailStatus = :1 AND linkedEvent.ID = :2"; "pending"; This.ID).first()

// ─── Weather setup & forecast labels (detail panel) ──────────────────────────

// Compact icons for list column
Function get plannedWeather() : Text
	return This._weatherLabel(This.weatherSetup)

Function get forecastWeather() : Text
	return This._weatherLabel(This.weatherForecast)

// Full readable labels for detail header
Function get setupLabel() : Text
	var $setup : Object:=This.weatherSetup
	If ($setup=Null)
		return "—"
	End if 
	var $cond : Text
	Case of 
		: ($setup.conditions="indifferent")
			return "🏢 Indoor"
		: ($setup.conditions="rain")
			$cond:="🌧 Rain-ready"
		: ($setup.conditions="sunny")
			$cond:="☀ Fair weather"
		Else 
			$cond:=$setup.conditions
	End case 
	var $temp : Text
	Case of 
		: ($setup.temperature="cold")
			$temp:="❄ Cold"
		: ($setup.temperature="hot")
			$temp:="🔥 Hot"
		Else 
			$temp:="🌡 Normal temp"
	End case 
	return $cond+" · "+$temp

Function get forecastLabel() : Text
	var $forecast : Object:=This.weatherForecast
	If ($forecast=Null)
		return "—"
	End if 
	var $cond : Text
	Case of 
		: ($forecast.conditions="indifferent")
			return "🏢 Indoor"
		: ($forecast.conditions="rain")
			$cond:="🌧 Rain expected"
		: ($forecast.conditions="sunny")
			$cond:="☀ Sunny"
		Else 
			$cond:=$forecast.conditions
	End case 
	var $temp : Text
	Case of 
		: ($forecast.temperature="cold")
			$temp:="❄ Cold"
		: ($forecast.temperature="hot")
			$temp:="🔥 Hot"
		Else 
			$temp:="🌡 Normal temp"
	End case 
	return $cond+" · "+$temp

// ─── Private helper ───────────────────────────────────────────────────────────

Function _weatherLabel($setup : Object) : Text
	If ($setup=Null)
		return "—"
	End if 
	If ($setup.conditions="indifferent")
		return "🏢 Indoor"
	End if 
	var $icon : Text
	Case of 
		: ($setup.conditions="rain")
			$icon:="🌧"
		: ($setup.conditions="sunny")
			$icon:="☀"
		Else 
			$icon:="❓"
	End case 
	var $temp : Text
	Case of 
		: ($setup.temperature="hot")
			$temp:="🔥"
		: ($setup.temperature="cold")
			$temp:="❄"
		Else 
			$temp:=""
	End case 
	return $icon+$temp
