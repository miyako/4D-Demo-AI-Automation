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
		: ($formEventCode=On Activate)
			This._refreshAiStatus()
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
	This._refreshAiStatus()
	
Function _refreshAiStatus()
	var $reasoningOk : Boolean:=cs.UIHelpers.me.isAliasConfigured("chat-reasoning")
	var $simpleOk : Boolean:=cs.UIHelpers.me.isAliasConfigured("chat-simple")
	var $embedOk : Boolean:=cs.UIHelpers.me.isAliasConfigured("embedding")
	var $allOk : Boolean:=$reasoningOk && $simpleOk && $embedOk
	
	var $l10n : Object:={}
	If (Get database localization(Current localization)="ja")
		$l10n.notConfigured:="未設定"
		$l10n.reasoning:="思考: "
		$l10n.simple:=" · 簡易: "
		$l10n.embed:=" · 埋め込み: "
		$l10n.missingModelAlias:="Missing model alias: "
		$l10n.and:=", "
	Else 
		$l10n.notConfigured:="not configured"
		$l10n.reasoning:="Reasoning: "
		$l10n.simple:=" · Simple: "
		$l10n.embed:=" · Embed: "
		$l10n.missingModelAlias:="Missing model alias: "
		$l10n.and:=" and "
	End if 
	
	If ($allOk)
		OBJECT SET VISIBLE(*; "btn_ai_connected"; True)
		OBJECT SET VISIBLE(*; "btn_ai_setup"; False)
		OBJECT SET VISIBLE(*; "text_ai_hint"; False)
	Else 
		OBJECT SET VISIBLE(*; "btn_ai_connected"; False)
		OBJECT SET VISIBLE(*; "btn_ai_setup"; True)
		var $missing : Collection:=New collection
		If (Not($reasoningOk))
			$missing.push("'chat-reasoning'")
		End if 
		If (Not($simpleOk))
			$missing.push("'chat-simple'")
		End if 
		If (Not($embedOk))
			$missing.push("'embedding'")
		End if 
		OBJECT SET TITLE(*; "text_ai_hint"; $l10n.missingModelAlias+$missing.join($l10n.and))
		OBJECT SET VISIBLE(*; "text_ai_hint"; True)
	End if 
	
	OBJECT SET ENABLED(*; "btn_rebuild_embeddings"; $embedOk)
	OBJECT SET ENABLED(*; "btn_reset_all"; $embedOk)
	
	var $providers : Object:=cs.AIKit.OpenAIProviders.new()
	var $aliases : Collection:=$providers.modelAliases()
	var $reasoningEntry : Object:=$aliases.query("name = :1"; "chat-reasoning").first()
	var $simpleEntry : Object:=$aliases.query("name = :1"; "chat-simple").first()
	var $embeddingEntry : Object:=$aliases.query("name = :1"; "embedding").first()
	var $reasoningLabel : Text:=$reasoningOk ? $reasoningEntry.model : $l10n.notConfigured
	var $simpleLabel : Text:=$simpleOk ? $simpleEntry.model : $l10n.notConfigured
	var $embedLabel : Text:=$embedOk ? $embeddingEntry.model : $l10n.notConfigured
	OBJECT SET TITLE(*; "text_footer"; $l10n.reasoning+$reasoningLabel+$l10n.simple+$simpleLabel+$l10n.embed+$embedLabel+" · Open-Meteo")
	
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
	
Function _checkEmbeddingReady() : Boolean
	return cs.UIHelpers.me.checkAliasOrPrompt("embedding")
	
Function _resetAll()
	If (Not(This._checkEmbeddingReady()))
		return 
	End if 
	CONFIRM("Reset ALL data?\n\nThis will delete all records and re-import everything from JSON files, including re-building service embeddings.")
	If (OK=1)
		var $progress : cs.FC_Progress:=cs.FC_Progress.new("Rebuilding all data…"; Formula(_resetAllWorkerJob))
		var $w : Integer:=Open form window("Progress"; Pop up form window; Horizontally centered; Vertically centered)
		DIALOG("Progress"; $progress)
		CLOSE WINDOW($w)
		ALERT("All data has been reset and rebuilt!\nService embeddings have been regenerated.")
	End if 
	
Function _rebuildEmbeddings()
	If (Not(This._checkEmbeddingReady()))
		return 
	End if 
	CONFIRM("Rebuild service embeddings?\n\nThis re-computes the AI search index for all services.\nUseful after translating or renaming service labels.\nMay take a minute.")
	If (OK=1)
		cs.DataSeeder.me.rebuildEmbeddings()
		ALERT("Service embeddings rebuilt successfully!")
	End if 
	
Function _openAiSetupDocs()
	cs.UIHelpers.me.openAiSetup()
	
Function _clearData()
	CONFIRM("Clear ALL data?\n\nThis will delete all records without re-importing.\nThe database will be empty use 'Reset & Rebuild All' to re-seed.")
	If (OK=1)
		cs.DataSeeder.me.clearAll()
		ALERT("All data cleared. The database is now empty.")
	End if 
	
Function _activate()
	
	var $x; $y; $r; $b; $window : Integer
	$window:=Current form window
	GET WINDOW RECT($x; $y; $r; $b; $window)
	SET WINDOW RECT($x; $y; $r; $b; $window)