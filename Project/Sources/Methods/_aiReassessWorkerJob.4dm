#DECLARE($window : Integer; $remainingJson : Text; $appliedLabel : Text; $eventID : Text)
// Runs in a worker — reassesses remaining AI actions then notifies the EventDetail form

var $remaining : Collection:=JSON Parse($remainingJson)
var $event : cs.EventEntity:=ds.Event.query("ID = :1"; $eventID).first()

var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
var $w : Integer:=$window

$advisor.reassessActionsAsync($remaining; $appliedLabel; $event; \
	Formula(CALL FORM($w; Formula(Form._onReassessmentDone($1)); $1)))
