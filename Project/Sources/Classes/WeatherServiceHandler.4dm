property method : Text
property dataType : Text
property result : Object
property event : cs.EventEntity
property service : cs.WeatherService

Class constructor($event : cs.EventEntity)
	
	This.event:=$event
	This.method:="GET"
	This.dataType:="auto"
	This.result:={success: False; riskLevel: "none"; weatherSummary: ""; weatherData: Null}
	This.service:=cs.WeatherService.me
	
Function num($value : Variant) : Real
	
	return $value#Null ? $value : 0
	
Function onResponse($request : 4D.HTTPRequest; $event : Object)
	
	If ($request.response.status#200)
		This.onError($request; $event)
		return 
	End if 
	
	var $body : Object
	If (Value type($request.response.body)=Is object)
		$body:=$request.response.body
	Else 
		$body:=JSON Parse(String($request.response.body))
	End if 
	
	If (($body=Null) || ($body.daily=Null))
		This.onError($request; $event)
		return 
	End if 
	
	// Extract day-0 data
	var $daily : Object:=$body.daily
	var $weatherCode : Integer
	var $maxTemp : Real
	var $minTemp : Real
	var $precip : Real
	var $wind : Real
	
	If (($daily.weathercode#Null) && ($daily.weathercode.length>0))
		$weatherCode:=This.num($daily.weathercode[0])
	End if 
	If (($daily.temperature_2m_max#Null) && ($daily.temperature_2m_max.length>0))
		$maxTemp:=This.num($daily.temperature_2m_max[0])
	End if 
	If (($daily.temperature_2m_min#Null) && ($daily.temperature_2m_min.length>0))
		$minTemp:=This.num($daily.temperature_2m_min[0])
	End if 
	If (($daily.precipitation_sum#Null) && ($daily.precipitation_sum.length>0))
		$precip:=This.num($daily.precipitation_sum[0])
	End if 
	If (($daily.windspeed_10m_max#Null) && ($daily.windspeed_10m_max.length>0))
		$wind:=This.num($daily.windspeed_10m_max[0])
	End if 
	
	This.result.weatherData:={maxTemperature: $maxTemp; minTemperature: $minTemp; precipitationMm: $precip; windSpeedKmh: $wind; weatherCode: $weatherCode; weatherDescription: This.service._codeToDescription($weatherCode)}
	This.result.riskLevel:=This.service._computeRisk($weatherCode; $precip; $wind; This.event.venue.venueType)
	This.result.weatherSummary:=This.service._buildSummary(This.result.weatherData; This.event.venue.city)
	This.result.rationalized:=This.service.rationalizeWeather(This.result.weatherData)
	
	This.event.weatherForecast:=This.result.rationalized
	// Compute alert based on setup vs forecast comparison
	This.event.weatherAlertLevel:=This.service.compareWeather(This.event.weatherSetup; This.result.rationalized; This.event.venueOption)
	This.event.weatherAlertJson:=JSON Parse(JSON Stringify(This.result))
	This.event.save()
	
Function onError($request : 4D.HTTPRequest; $event : Object)
	
	This.result:=This.service._offlineFallback(This.event.venue.venueType)
	This.event.weatherAlertLevel:="none"
	This.event.save()
	
Function onTerminate($request : 4D.HTTPRequest; $event : Object)
	
	This.service.fetchedForEvent(This.event)