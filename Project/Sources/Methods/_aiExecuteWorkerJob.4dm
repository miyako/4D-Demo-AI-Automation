//%attributes = {"invisible":true}
#DECLARE($window : Integer; $hiddenPrompt : Text; $contextJson : Text)
// Runs in a worker calls AI execute action then notifies the EventDetail form.
// The action object is stored in AIWorkerContext singleton by the caller (no JSON round-trip).

var $context : Object:=JSON Parse($contextJson)
var $w : Integer:=$window

// JSON Parse may auto-convert "yyyy-MM-dd" strings to 4D Date type normalize back to Text
If (Value type($context.eventDate)=Is date)
$context.eventDate:=String(Date($context.eventDate); "yyyy-MM-dd")
End if 

var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
If (($context.contractRef#Null) && ($context.contractRef#""))
	$advisor._contractRef:=String($context.contractRef)
Else 
	$advisor._contractRef:=cs.AIWorkerContext.me.getContractRef($w)
End if 
$advisor.executeActionAsync($hiddenPrompt; $context; \
Formula(CALL FORM($w; Formula(Form._onExecutionDone($1)); $1)))
