// WeatherService.4dm
// Appel Open-Meteo pour récupérer les prévisions météo par venue (lat/lng)
// Cache dans Event.weatherAlertJson — fallback sur données pré-semées si offline

property _baseURL : Text

singleton Class constructor()
	This._baseURL:="https://api.open-meteo.com/v1/forecast"

// ─── Fetch forecast for a single event ───────────────────────────────────────
// Returns: {success; riskLevel; weatherSummary; weatherData; error}
Function fetchForEvent($event : cs.EventEntity) : Object
	var $result : Object:={success: False; riskLevel: "none"; weatherSummary: ""; weatherData: Null}

	If ($event=Null)
		$result.error:="Event entity is null"
		return $result
	End if

	var $venue : cs.VenueEntity:=$event.venue
	If ($venue=Null)
		$result.error:="No venue linked to event"
		return $result
	End if

	var $lat : Real:=$venue.latitude
	var $lng : Real:=$venue.longitude
	var $eventDate : Date:=$event.eventDate

	If (($lat=0) && ($lng=0))
		$result.error:="Venue has no coordinates"
		return $result
	End if

	// Build Open-Meteo URL
	var $dateStr : Text:=String($eventDate; "yyyy-MM-dd")
	var $url : Text:=This._baseURL
	$url:=$url+"?latitude="+String($lat; "0.0000")
	$url:=$url+"&longitude="+String($lng; "0.0000")
	$url:=$url+"&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_sum,windspeed_10m_max"
	$url:=$url+"&start_date="+$dateStr
	$url:=$url+"&end_date="+$dateStr
	$url:=$url+"&timezone=auto"

	var $response : Object
	var $http : 4D.HTTPRequest

	If ($url="")
		$result.error:="URL construction failed"
		return $result
	End if 

	$http:=4D.HTTPRequest.new($url; {method: "GET"; dataType: "auto"})
	$http.wait(10000)

	If ($http.response=Null)
		// Offline fallback
		$result:=This._offlineFallback($venue.venueType)
		return $result
	End if

	If ($http.response.status#200)
		$result:=This._offlineFallback($venue.venueType)
		return $result
	End if

	var $body : Object
	If (Value type($http.response.body)=Is object)
		$body:=$http.response.body
	Else
		$body:=JSON Parse(String($http.response.body))
	End if

	If (($body=Null) || ($body.daily=Null))
		$result:=This._offlineFallback($venue.venueType)
		return $result
	End if

	// Extract day-0 data
	var $daily : Object:=$body.daily
	var $weatherCode : Integer
	var $maxTemp : Real
	var $minTemp : Real
	var $precip : Real
	var $wind : Real

	If (($daily.weathercode#Null) && ($daily.weathercode.length>0))
		$weatherCode:=$daily.weathercode[0]
	End if
	If (($daily.temperature_2m_max#Null) && ($daily.temperature_2m_max.length>0))
		$maxTemp:=$daily.temperature_2m_max[0]
	End if
	If (($daily.temperature_2m_min#Null) && ($daily.temperature_2m_min.length>0))
		$minTemp:=$daily.temperature_2m_min[0]
	End if
	If (($daily.precipitation_sum#Null) && ($daily.precipitation_sum.length>0))
		$precip:=$daily.precipitation_sum[0]
	End if
	If (($daily.windspeed_10m_max#Null) && ($daily.windspeed_10m_max.length>0))
		$wind:=$daily.windspeed_10m_max[0]
	End if

	$result.weatherData:={maxTemperature: $maxTemp; minTemperature: $minTemp; precipitationMm: $precip; windSpeedKmh: $wind; weatherCode: $weatherCode; weatherDescription: This._codeToDescription($weatherCode)}
	$result.riskLevel:=This._computeRisk($weatherCode; $precip; $wind; $venue.venueType)
	$result.weatherSummary:=This._buildSummary($result.weatherData; $venue.city)
	$result.rationalized:=This.rationalizeWeather($result.weatherData)
	$result.success:=True

	return $result

// ─── Batch update all upcoming events (next 30 days) ─────────────────────────
// Calls _onWeatherBatchComplete formula when done
Function refreshUpcomingEvents($callback : 4D.Function)
	var $today : Date:=Current date
	var $cutoff : Date:=$today+30
	var $events : cs.EventSelection:=ds.Event.query("status = :1 AND eventDate >= :2 AND eventDate <= :3"; "confirmed"; $today; $cutoff)

	var $evt : cs.EventEntity
	var $weather : Object
	For each ($evt; $events)
		$weather:=This.fetchForEvent($evt)
		If ($weather.success)
			// Store rationalized forecast on event
			$evt.weatherForecast:=$weather.rationalized
			// Compute alert based on setup vs forecast comparison
			$evt.weatherAlertLevel:=This.compareWeather($evt.weatherSetup; $weather.rationalized; $evt.venueOption)
			$evt.weatherAlertJson:=JSON Parse(JSON Stringify($weather))
		Else 
			$evt.weatherAlertLevel:="none"
		End if
		$evt.save()
	End for each

	If ($callback#Null)
		$callback.call(Null)
	End if

// ─── Rationalize raw weather data into comparable format ──────────────────────
// Converts Open-Meteo data to {conditions; temperature} matching weatherSetup format
Function rationalizeWeather($weatherData : Object) : Object
	If ($weatherData=Null)
		return {conditions: "sunny"; temperature: "normal"}
	End if 

	var $conditions : Text
	var $temperature : Text

	// Conditions: based on WMO weather code and precipitation
	var $code : Integer:=$weatherData.weatherCode
	var $precip : Real:=$weatherData.precipitationMm
	If (($code>=51) || ($precip>=2))
		$conditions:="rain"
	Else 
		$conditions:="sunny"
	End if 

	// Temperature: based on max temperature
	var $maxTemp : Real:=$weatherData.maxTemperature
	If ($maxTemp>=30)
		$temperature:="hot"
	Else 
		If ($maxTemp<10)
			$temperature:="cold"
		Else 
			$temperature:="normal"
		End if 
	End if 

	return {conditions: $conditions; temperature: $temperature}

// ─── Assess effective planned weather from current service lines ─────────────
// Checks if shelter/rain-protection structures are present to derive conditions.
// Returns "rain" or "sunny" for outdoor events; "" if no change is applicable.
Function assessSetupFromLines($lines : Collection; $currentConditions : Text) : Text
	// Indoor events are always indifferent — never change
	If ($currentConditions="indifferent")
		return ""
	End if
	// Rain-protection structures: tents, chapiteaux, pagodas
	var $rainKeywords : Collection:=["tente"; "chapiteau"; "pagode"; "stretch"; "bâche"; "tent"; "canopy"; "shelter"]
	var $hasRainProtection : Boolean:=False
	var $line : Object
	For each ($line; $lines)
		var $label : Text:=Lowercase($line.serviceLabel)
		var $k : Text
		For each ($k; $rainKeywords)
			If (Position($k; $label)>0)
				$hasRainProtection:=True
			End if
		End for each
	End for each
	If ($hasRainProtection)
		return "rain"
	Else
		return "sunny"
	End if

// ─── Compare contracted vs forecast weather ──────────────────────────────────
// Returns alert level: "none", "watch", "warning"
Function compareWeather($setup : Object; $forecast : Object; $venueOption : Text) : Text
	// Indoor events: never alert
	If ($venueOption="indoor")
		return "none"
	End if 
	If (($setup=Null) || ($forecast=Null))
		return "none"
	End if 
	If ($setup.conditions="indifferent")
		return "none"
	End if 

	var $conditionsMismatch : Boolean:=($setup.conditions#$forecast.conditions)
	var $tempMismatch : Boolean:=($setup.temperature#$forecast.temperature)

	// Worst case: planned sunny but rain forecast
	If ($conditionsMismatch)
		If (($setup.conditions="sunny") && ($forecast.conditions="rain"))
			return "warning"
		End if 
		// Planned rain but sunny: watch (opportunity, not danger)
		return "watch"
	End if 

	// Temperature mismatch only
	If ($tempMismatch)
		return "watch"
	End if 

	return "none"

// ─── Risk computation ─────────────────────────────────────────────────────────
Function _computeRisk($code : Integer; $precip : Real; $wind : Real; $venueType : Text) : Text
	// WMO weather codes: 0=clear, 1-3=partly cloudy, 45-48=fog,
	// 51-67=drizzle/rain, 71-77=snow, 80-82=showers, 95=thunderstorm, 99=hail
	var $isOutdoor : Boolean:=(($venueType="outdoor") || ($venueType="mixed"))

	// Critical conditions (all venue types)
	If ($code>=95)
		return "critical"
	End if
	If ($wind>=80)
		return "critical"
	End if

	// Warning conditions
	If ($isOutdoor)
		If (($code>=80) && ($code<95))
			return "warning"
		End if
		If ($precip>=15)
			return "warning"
		End if
		If ($wind>=50)
			return "warning"
		End if
	End if

	// Watch conditions
	If ($isOutdoor)
		If (($code>=51) && ($code<80))
			return "watch"
		End if
		If ($precip>=5)
			return "watch"
		End if
		If ($wind>=35)
			return "watch"
		End if
	Else
		// Indoor venues: only extreme conditions
		If (($code>=80) && ($precip>=30))
			return "watch"
		End if
	End if

	return "none"

// ─── Offline fallback (stable, predictable) ───────────────────────────────────
Function _offlineFallback($venueType : Text) : Object
	var $r : Object:={success: True; riskLevel: "none"; weatherData: {maxTemperature: 22; minTemperature: 15; precipitationMm: 0; windSpeedKmh: 12; weatherCode: 1; weatherDescription: "Partly cloudy"}; weatherSummary: "Partly cloudy, 22°C expected. [Offline data]"}
	$r.rationalized:=This.rationalizeWeather($r.weatherData)
	If ($venueType="outdoor")
		$r.riskLevel:="watch"
		$r.weatherData.precipitationMm:=8
		$r.weatherData.weatherCode:=61
		$r.weatherData.weatherDescription:="Light rain"
		$r.weatherSummary:="Light rain possible (8mm), wind 12 km/h. [Offline data]"
		$r.rationalized:=This.rationalizeWeather($r.weatherData)
	End if
	return $r

// ─── WMO code → description ───────────────────────────────────────────────────
Function _codeToDescription($code : Integer) : Text
	Case of 
		: ($code=0)
			return "Clear sky"
		: ($code<=3)
			return "Partly cloudy"
		: ($code<=48)
			return "Fog"
		: ($code<=57)
			return "Drizzle"
		: ($code<=67)
			return "Rain"
		: ($code<=77)
			return "Snow"
		: ($code<=82)
			return "Rain showers"
		: ($code<=86)
			return "Snow showers"
		: ($code<=95)
			return "Thunderstorm"
		: ($code<=99)
			return "Thunderstorm with hail"
		Else 
			return "Unknown"
	End case 

// ─── Build readable summary ───────────────────────────────────────────────────
Function _buildSummary($data : Object; $city : Text) : Text
	var $s : Text:=""
	If ($data#Null)
		$s:=$data.weatherDescription+" in "+$city
		$s:=$s+", "+String(Round($data.maxTemperature; 0))+"°C max"
		If ($data.precipitationMm>0)
			$s:=$s+", "+String(Round($data.precipitationMm; 1))+"mm rain expected"
		End if
		If ($data.windSpeedKmh>30)
			$s:=$s+", "+String(Round($data.windSpeedKmh; 0))+" km/h wind"
		End if
	End if
	return $s
