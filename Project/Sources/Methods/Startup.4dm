//%attributes = {}
// Startup.4dm
// Startup method for the Event Pulse application
// Called automatically by the Database Method "On Startup"
// AI provider and models configured in AIProviders.json

// Open the main hub — data seeding is triggered manually via the Init button

var $w : Integer:=Open form window("Home"; Plain form window; Horizontally centered; Vertically centered)
DIALOG("Home")
CLOSE WINDOW($w)
