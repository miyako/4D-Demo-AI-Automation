// UIHelpers.4dm
// UI functions shared between form controllers (AI action buttons)

singleton Class constructor()

// ─── Masquer les 4 boutons d'action IA ────────────────────────────────────────
Function resetActionButtons()
	var $btns : Collection:=["btn_ai_action1"; "btn_ai_action2"; "btn_ai_action3"; "btn_ai_action4"]
	var $btn : Text
	For each ($btn; $btns)
		OBJECT SET VISIBLE(*; $btn; False)
		OBJECT SET TITLE(*; $btn; "")
	End for each 
	OBJECT SET TITLE(*; "text_ai_validation_badge"; "")

// ─── Display AI action buttons (max 4), stacked from the bottom ─────────────────
// Buttons are pre-positioned bottom-to-top in the form (action4=680, action3=624, action2=568, action1=512)
// We show the last N slots so actions always appear just above the analyze button.
// Returns a Collection[4] mapping slot index → action index (or -1 if unused).
Function showActionButtons($actions : Collection) : Collection
	var $btnNames : Collection:=["btn_ai_action1"; "btn_ai_action2"; "btn_ai_action3"; "btn_ai_action4"]
	var $maxAct : Integer:=$actions.length
	If ($maxAct>4)
		$maxAct:=4
	End if 
	// Build slot→action map: slot 0-3 maps to action index or -1
	var $map : Collection:=[-1; -1; -1; -1]
	// Show bottom N buttons: last $maxAct slots, action[0] → bottommost visible slot
	var $i : Integer
	For ($i; 0; $maxAct-1)
		var $slot : Integer:=4-$maxAct+$i  // e.g. 1 action → slot=3; 2 actions → slots 2,3
		$map[$slot]:=$i
		OBJECT SET VISIBLE(*; $btnNames[$slot]; True)
		OBJECT SET TITLE(*; $btnNames[$slot]; $actions[$i].label)
	End for 
	return $map

// ─── AI alias helpers ─────────────────────────────────────────────────────────

// Returns True if the named model alias is configured (non-empty model value)
Function isAliasConfigured($alias : Text) : Boolean
	var $entry : Object:=cs.AIKit.OpenAIProviders.new().modelAliases().query("name = :1"; $alias).first()
	return ($entry#Null) && ($entry.model#"") && ($entry.model#Null)

// Opens AI settings in dev mode, or the online doc page otherwise
Function openAiSetup()
	If (Application type=0)
		OPEN SETTINGS WINDOW("/Database/AI")
	Else 
		OPEN URL("https://developer.4d.com/docs/settings/ai")
	End if 

// Checks that $alias is configured; if not, prompts and offers to open settings.
// Returns True if ready, False if not configured.
Function checkAliasOrPrompt($alias : Text) : Boolean
	If (This.isAliasConfigured($alias))
		return True
	End if 
	If (Application type=0)
		CONFIRM("No '"+$alias+"' model alias is configured.\n\nOpen AI settings now?")
		If (OK=1)
			OPEN SETTINGS WINDOW("/Database/AI")
		End if 
	Else 
		ALERT("No '"+$alias+"' model alias is configured.\n\nPlease set up a '"+$alias+"' model alias in the AI settings.\nSee: https://developer.4d.com/docs/settings/ai")
	End if 
	return False

// ─── Spinner constants ────────────────────────────────────────────────────────

// Returns the braille spinner frame sequence used by all form spinners
Function spinnerFrames() : Collection
	return ["⠋"; "⠙"; "⠹"; "⠸"; "⠼"; "⠴"; "⠦"; "⠧"; "⠇"; "⠏"]

// ─── Window utilities ─────────────────────────────────────────────────────────

// Resizes the current form window to $width, keeping height and position,
// clamped to the screen the window currently lives on.
Function resizeWindowWidth($width : Integer)
	var $curL; $curT; $curR; $curB : Integer
	GET WINDOW RECT($curL; $curT; $curR; $curB; Current form window)
	var $height : Integer:=$curB-$curT
	var $screenL; $screenT; $screenR; $screenB : Integer
	var $sL; $sT; $sR; $sB : Integer
	var $i : Integer
	$screenL:=0
	$screenT:=0
	$screenR:=0
	$screenB:=0
	For ($i; 1; Count screens)
		SCREEN COORDINATES($sL; $sT; $sR; $sB; $i)
		If (($curL>=$sL) && ($curL<$sR))
			$screenL:=$sL
			$screenT:=$sT
			$screenR:=$sR
			$screenB:=$sB
		End if 
	End for 
	If ($screenR=$screenL)
		SCREEN COORDINATES($screenL; $screenT; $screenR; $screenB)
	End if 
	If (($curL+$width)>$screenR)
		$curL:=$screenR-$width
		If ($curL<$screenL)
			$curL:=$screenL
		End if 
	End if 
	SET WINDOW RECT($curL; $curT; $curL+$width; $curT+$height; Current form window)
