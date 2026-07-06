//%attributes = {"invisible":true}
#DECLARE($window : Integer)
// Runs in "_progressWorker" full reset + rebuild of all data
// Called by FC_Progress via CALL WORKER

cs.DataSeeder.me.resetAll()

// Notify the progress form to close itself
CALL FORM($window; Formula(Form._onDone()))
