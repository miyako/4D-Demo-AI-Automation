// UIHelpers.4dm
// Fonctions UI partagées entre les form controllers (boutons d'action IA)

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

// ─── Afficher les boutons d'action IA (max 4), empilés depuis le bas ──────────
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

// ─── Badges de type email ─────────────────────────────────────────────────────
// Version courte (listes)
Function typeBadge($type : Text) : Text
	Case of 
		: ($type="quote")
			return "📋 Quote"
		: ($type="modification")
			return "🌧 Modification"
		: ($type="info")
			return "ℹ Info"
		Else 
			return $type
	End case 

// Version longue (détail)
Function typeBadgeFull($type : Text) : Text
	Case of 
		: ($type="quote")
			return "📋 QUOTE REQUEST"
		: ($type="modification")
			return "🌧 MODIFICATION"
		: ($type="info")
			return "ℹ INFO"
		Else 
			return $type
	End case 
