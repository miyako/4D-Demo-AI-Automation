#DECLARE($window : Integer; $emailID : Text; $eventID : Text; $linesJson : Text)
// Runs in a worker — calls AI email modification analysis then notifies the EventDetail form
// Email is always linked to a known event (no disambiguation needed)

var $email : cs.EmailEntity:=ds.Email.query("ID = :1"; $emailID).first()
var $event : cs.EventEntity:=ds.Event.query("ID = :1"; $eventID).first()
var $lines : Collection:=JSON Parse($linesJson)

var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
var $w : Integer:=$window

$advisor.analyzeLinkedEmailAsync($email; $event; $lines; \
	Formula(CALL FORM($w; Formula(Form._onEmailAnalysisDone($1)); $1)))
