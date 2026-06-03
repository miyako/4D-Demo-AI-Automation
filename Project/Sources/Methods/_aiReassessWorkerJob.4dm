#DECLARE($window : Integer; $remainingJson : Text; $appliedLabel : Text; $linesJson : Text)
// Runs in a worker — reassesses remaining AI actions then notifies the EventDetail form

var $remaining : Collection:=JSON Parse($remainingJson)
var $lines : Collection:=JSON Parse($linesJson)

var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
var $w : Integer:=$window

$advisor.reassessActionsAsync($remaining; $appliedLabel; $lines; \
	Formula(CALL FORM($w; Formula(Form._onReassessmentDone($1)); $1)))
