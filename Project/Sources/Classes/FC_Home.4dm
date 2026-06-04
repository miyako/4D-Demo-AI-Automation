// FC_Home.4dm
// Home form controller – navigation hub for the 3 modules

property statusText : Text

Class constructor()
	This.statusText:="● AI Connected"

//MARK: - Form & form objects event handlers
Function formEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Load)
			This._onLoad()
	End case 

Function btnEventsEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._openEvents()
	End case 

Function btnServicesEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._openServices()
	End case 

Function btnVenuesEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._openVenues()
	End case 

Function btnResetAllEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._resetAll()
	End case 

Function btnRebuildEmbeddingsEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._rebuildEmbeddings()
	End case 

Function btnClearDataEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._clearData()
	End case 

Function btnAiSetupEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._openAiSetupDocs()
	End case 

//MARK: - Private
Function _onLoad()
	var $providers : Object:=cs.AIKit.OpenAIProviders.new()
	var $providerList : Collection:=$providers.list()
	var $aliases : Collection:=$providers.modelAliases()
	var $chatEntry : Object:=$aliases.query("name = :1"; "chat").first()
	var $aiOk : Boolean:=($providerList.length>0) && ($chatEntry#Null) && ($chatEntry.model#"") && ($chatEntry.model#Null)
	
	If ($aiOk)
		OBJECT SET VISIBLE(*; "btn_ai_connected"; True)
		OBJECT SET VISIBLE(*; "btn_ai_setup"; False)
	Else 
		OBJECT SET VISIBLE(*; "btn_ai_connected"; False)
		OBJECT SET VISIBLE(*; "btn_ai_setup"; True)
	End if 
	
	// Build "Powered by" footer from model aliases
	var $embeddingEntry : Object:=$aliases.query("name = :1"; "embedding").first()
	var $chatLabel : Text:=$chatEntry ? $chatEntry.model : "?"
	var $embedLabel : Text:=$embeddingEntry ? $embeddingEntry.model : "?"
	OBJECT SET TITLE(*; "text_footer"; "Powered by "+$chatLabel+" (chat) · "+$embedLabel+" (embedding) · Open-Meteo")

Function _openEvents()
	var $w : Integer:=Open form window("EventList"; Plain form window)
	DIALOG("EventList")
	CLOSE WINDOW($w)

Function _openServices()
	var $w : Integer:=Open form window("ServiceBrowser"; Plain form window)
	DIALOG("ServiceBrowser")
	CLOSE WINDOW($w)

Function _openVenues()
	var $w : Integer:=Open form window("VenueBrowser"; Plain form window)
	DIALOG("VenueBrowser")
	CLOSE WINDOW($w)

Function _resetAll()
	CONFIRM("Reset ALL data?\n\nThis will delete all records and re-import everything from JSON files, including re-building service embeddings.")
	If (OK=1)
		var $progress : cs.FC_Progress:=cs.FC_Progress.new("Rebuilding all data…"; Formula(_resetAllWorkerJob))
		var $w : Integer:=Open form window("Progress"; Pop up form window; Horizontally centered; Vertically centered)
		DIALOG("Progress"; $progress)
		CLOSE WINDOW($w)
		ALERT("All data has been reset and rebuilt!\nService embeddings have been regenerated.")
	End if 

Function _rebuildEmbeddings()
	CONFIRM("Rebuild service embeddings?\n\nThis re-computes the AI search index for all services.\nUseful after translating or renaming service labels.\nMay take a minute.")
	If (OK=1)
		cs.DataSeeder.me.rebuildEmbeddings()
		ALERT("Service embeddings rebuilt successfully!")
	End if 

Function _openAiSetupDocs()
	OPEN URL("https://developer.4d.com/docs/settings/ai")

Function _clearData()
	CONFIRM("Clear ALL data?\n\nThis will delete all records without re-importing.\nThe database will be empty — use 'Reset & Rebuild All' to re-seed.")
	If (OK=1)
		cs.DataSeeder.me.clearAll()
		ALERT("All data cleared. The database is now empty.")
	End if 
