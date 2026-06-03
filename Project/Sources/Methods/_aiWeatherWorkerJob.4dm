#DECLARE($window : Integer; $eventID : Text; $weatherFetchJson : Text; $linesJson : Text)
// Runs in a worker — calls AI weather risk analysis then notifies the EventDetail form

var $event : cs.EventEntity:=ds.Event.query("ID = :1"; $eventID).first()
var $weatherFetch : Object:=JSON Parse($weatherFetchJson)
var $lines : Collection:=JSON Parse($linesJson)

var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
var $w : Integer:=$window
var $wf : Object:=$weatherFetch

$advisor.analyzeWeatherRiskAsync($event; $weatherFetch.weatherData; $lines; \
	Formula(CALL FORM($w; Formula(Form._onWeatherAnalysisDone($1; $wf)); $1)))
