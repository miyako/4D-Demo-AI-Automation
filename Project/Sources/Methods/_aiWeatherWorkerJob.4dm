//%attributes = {"invisible":true}
#DECLARE($window : Integer; $eventID : Text)
// Runs in a worker calls AI weather risk analysis then notifies the EventDetail form

var $event : cs.EventEntity:=ds.Event.query("ID = :1"; $eventID).first()

var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
$advisor._contractRef:=cs.AIWorkerContext.me.getContractRef($window)
var $w : Integer:=$window

$advisor.analyzeWeatherRiskAsync($event; \
	Formula(CALL FORM($w; Formula(Form._onWeatherAnalysisDone($1)); $1)))
