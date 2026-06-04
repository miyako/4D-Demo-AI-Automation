// AIWorkerContext.4dm
// Session singleton — stores pending AI data per form window, keyed by window ID.
// Shared across all processes in the same session (form process + workers).
// Eliminates JSON round-trip serialization of action objects and existing lines.

session singleton Class constructor()
	This.pendingActions:={}
	This.pendingExistingLines:={}

Function storeAction($windowID : Integer; $action : Object)
	This.pendingActions[String($windowID)]:=$action

Function getAction($windowID : Integer) : Object
	return This.pendingActions[String($windowID)]

Function storeExistingLines($windowID : Integer; $lines : Collection)
	This.pendingExistingLines[String($windowID)]:=$lines

Function getExistingLines($windowID : Integer) : Collection
	var $lines:=This.pendingExistingLines[String($windowID)]
	return ($lines#Null) ? $lines : []

Function clearAction($windowID : Integer)
	OB REMOVE(This.pendingActions; String($windowID))
	OB REMOVE(This.pendingExistingLines; String($windowID))
