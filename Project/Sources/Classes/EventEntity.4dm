// EventEntity.4dm Computed attributes for the Event entity
// Used by the EventList entity-selection listbox and EventDetail display

Class extends Entity

// ─── Display helpers ─────────────────────────────────────────────────────────

Function get eventDateStr() : Text
	//return String(This.eventDate; "dd/MM/yyyy")
	return String(This.eventDate; "yyyy.MM.dd")
	
Function get clientName() : Text
	var $c : cs.ClientEntity:=This.client
	return $c ? $c.companyName : ""
	
Function get venueName() : Text
	var $v : cs.VenueEntity:=This.venue
	return $v ? $v._name : ""
	
Function get venueCity() : Text
	var $v : cs.VenueEntity:=This.venue
	return $v ? $v.city : ""
	
Function get guestCountStr() : Text
	return String(This.guestCount)
	
Function get guestCountLabel() : Text
	return String(This.guestCount)+" 人"
	
Function get eventDateLong() : Text
	return String(This.eventDate; "EEEE dd MMMM yyyy")
	return String(This.eventDate; "EEEE yyyy MMMM dd")
	
Function get contactInfo() : Text
	var $c : cs.ClientEntity:=This.client
	return $c ? $c.contactName+" · "+$c.email : ""
	
Function get venueLabel() : Text
	var $v : cs.VenueEntity:=This.venue
	return $v ? $v.name+" – "+$v.city+", "+$v.country : ""
	
	// ─── Status labels ────────────────────────────────────────────────────────────
	
	// Short badge for listbox column
Function get statusBadge() : Text
	Case of 
		: (This.status="confirmed")
			return "確定"
		: (This.status="quote")
			return "商談中"
		: (This.status="completed")
			return "終了"
		: (This.status="cancelled")
			return "中止"
		Else 
			return This.status
	End case 
	
	// Full label with icon for detail header
Function get statusLabel() : Text
	Case of 
		: (This.status="confirmed")
			return "✅ 確定"
		: (This.status="quote")
			return "💬 商談中"
		: (This.status="completed")
			return "✔ 終了"
		: (This.status="cancelled")
			return "❌ 中止"
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
			return "🚨 危険レベル – 緊急対応が必要"
		: (This.weatherAlertLevel="warning")
			return "⛈ 警告レベル – 注意が必要"
		: (This.weatherAlertLevel="watch")
			return "🌧 不安定 – 監視が必要"
		Else 
			return "☀️ 天候リスクなし"
	End case 
	
	// venueOption is a real field ("indoor"/"outdoor") use venueOptionIcon for the emoji column
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
		return ""
	End if 
	var $cond : Text
	Case of 
		: ($setup.conditions="indifferent")
			return "🏢 屋内"
		: ($setup.conditions="rain")
			$cond:="🌧 雨天対応"
		: ($setup.conditions="sunny")
			$cond:="☀️ 晴天"
		Else 
			$cond:=$setup.conditions
	End case 
	var $temp : Text
	Case of 
		: ($setup.temperature="cold")
			$temp:="❄ 厳寒"
		: ($setup.temperature="hot")
			$temp:="🔥 猛暑"
		Else 
			$temp:="🌡 平常"
	End case 
	return $cond+" · "+$temp
	
Function get forecastLabel() : Text
	var $forecast : Object:=This.weatherForecast
	If ($forecast=Null)
		return ""
	End if 
	var $cond : Text
	Case of 
		: ($forecast.conditions="indifferent")
			return "🏢 屋内"
		: ($forecast.conditions="rain")
			$cond:="🌧 雨天"
		: ($forecast.conditions="sunny")
			$cond:="☀️ 晴天"
		Else 
			$cond:=$forecast.conditions
	End case 
	var $temp : Text
	Case of 
		: ($forecast.temperature="cold")
			$temp:="❄ 厳寒"
		: ($forecast.temperature="hot")
			$temp:="🔥 猛暑"
		Else 
			$temp:="🌡 平常"
	End case 
	return $cond+" · "+$temp
	
	// ─── Private helper ───────────────────────────────────────────────────────────
	
Function _weatherLabel($setup : Object) : Text
	If ($setup=Null)
		return ""
	End if 
	If ($setup.conditions="indifferent")
		return "🏢 屋内"
	End if 
	var $icon : Text
	Case of 
		: ($setup.conditions="rain")
			$icon:="🌧"
		: ($setup.conditions="sunny")
			$icon:="☀️"
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
	