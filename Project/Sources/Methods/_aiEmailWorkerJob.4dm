#DECLARE($window : Integer; $emailID : Text; $candidateEventsJson : Text; $linesJson : Text)
// Runs in a worker — calls AI email modification analysis then notifies the EventDetail form

var $email : cs.EmailEntity:=ds.Email.query("ID = :1"; $emailID).first()
var $candidateEvents : Collection:=JSON Parse($candidateEventsJson)
var $lines : Collection:=JSON Parse($linesJson)

var $advisor : cs.AIAdvisor:=cs.AIAdvisor.new()
var $w : Integer:=$window

$advisor.analyzeModificationEmailAsync($email; $candidateEvents; $lines; \
	Formula(CALL FORM($w; Formula(Form._onEmailAnalysisDone($1)); $1)))
