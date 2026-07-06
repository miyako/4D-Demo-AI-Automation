//%attributes = {"invisible":true}
#DECLARE($window : Integer; $emailID : Text; $eventID : Text)
// Runs in a worker calls AI email modification analysis then notifies the EventDetail form
// Email is always linked to a known event (no disambiguation needed)

var $email : cs.EmailEntity:=ds.Email.query("ID = :1"; $emailID).first()
var $event : cs.EventEntity:=ds.Event.query("ID = :1"; $eventID).first()

var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
$advisor._contractRef:=cs.AIWorkerContext.me.getContractRef($window)
var $w : Integer:=$window

$advisor.analyzeLinkedEmailAsync($email; $event; \
	Formula(CALL FORM($w; Formula(Form._onEmailAnalysisDone($1)); $1)))
