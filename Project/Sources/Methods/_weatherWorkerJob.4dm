//%attributes = {"invisible":true}
#DECLARE($window : Integer)
// Runs in "weatherWorker" fetches weather for upcoming events, then notifies the form

var $weather : cs.WeatherService:=cs.WeatherService.me
$weather.refreshUpcomingEvents(Null)

// Notify the calling form window that the job is done
// Form is evaluated in the form's process context (not the worker's copy)
CALL FORM($window; Formula(Form._onWeatherDone()))
