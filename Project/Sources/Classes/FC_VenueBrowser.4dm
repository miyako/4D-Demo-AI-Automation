// FC_VenueBrowser.4dm
// Read-only browser for venues with indoor/outdoor options and rental pricing

property venues : Collection
property activeFilter : Text
property searchText : Text

Class extends FC

Class constructor()
	
	Super()
	This.venues:=[]
	This.activeFilter:="all"
	This.searchText:=""
	
	//MARK: - Form & form objects event handlers
Function formEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Load)
			This._onLoad()
	End case 
	
Function btnFilterAllEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("all")
	End case 
	
Function btnFilterBothEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("both")
	End case 
	
Function btnFilterIndoorEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("indoor")
	End case 
	
Function btnFilterOutdoorEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("outdoor")
	End case 
	
Function inputSearchEventHandler($formEventCode : Integer)
	
	Case of 
		: ($formEventCode=On After Edit)
			//: ($formEventCode=On Data Change) | ($formEventCode=On After Keystroke)
			//This.searchText:=OBJECT Get value("input_search")
			This.searchText:=Get edited text
			This._loadVenues()
	End case 
	
	//MARK: - Private
Function _onLoad()
	This._loadVenues()
	
Function _setFilter($filter : Text)
	This.activeFilter:=$filter
	If (False)
		Case of 
			: ($filter="both")
				
				OBJECT SET VISIBLE(*; "btn_filter_both-active"; True)
				OBJECT SET VISIBLE(*; "btn_filter_both-inactive"; False)
				
				OBJECT SET VISIBLE(*; "btn_filter_all-active"; False)
				OBJECT SET VISIBLE(*; "btn_filter_all-inactive"; True)
				
				OBJECT SET VISIBLE(*; "btn_filter_indoor-active"; False)
				OBJECT SET VISIBLE(*; "btn_filter_indoor-inactive"; True)
				
				OBJECT SET VISIBLE(*; "btn_filter_outdoor-active"; False)
				OBJECT SET VISIBLE(*; "btn_filter_outdoor-inactive"; True)
				
			: ($filter="indoor")
				
				OBJECT SET VISIBLE(*; "btn_filter_both-active"; False)
				OBJECT SET VISIBLE(*; "btn_filter_both-inactive"; True)
				
				OBJECT SET VISIBLE(*; "btn_filter_all-active"; False)
				OBJECT SET VISIBLE(*; "btn_filter_all-inactive"; True)
				
				OBJECT SET VISIBLE(*; "btn_filter_indoor-active"; True)
				OBJECT SET VISIBLE(*; "btn_filter_indoor-inactive"; False)
				
				OBJECT SET VISIBLE(*; "btn_filter_outdoor-active"; False)
				OBJECT SET VISIBLE(*; "btn_filter_outdoor-inactive"; True)
				
			: ($filter="outdoor")
				
				OBJECT SET VISIBLE(*; "btn_filter_both-active"; False)
				OBJECT SET VISIBLE(*; "btn_filter_both-inactive"; True)
				
				OBJECT SET VISIBLE(*; "btn_filter_all-active"; False)
				OBJECT SET VISIBLE(*; "btn_filter_all-inactive"; True)
				
				OBJECT SET VISIBLE(*; "btn_filter_indoor-active"; False)
				OBJECT SET VISIBLE(*; "btn_filter_indoor-inactive"; True)
				
				OBJECT SET VISIBLE(*; "btn_filter_outdoor-active"; True)
				OBJECT SET VISIBLE(*; "btn_filter_outdoor-inactive"; False)
				
			: ($filter="all")
				
				OBJECT SET VISIBLE(*; "btn_filter_both-active"; False)
				OBJECT SET VISIBLE(*; "btn_filter_both-inactive"; True)
				
				OBJECT SET VISIBLE(*; "btn_filter_all-active"; True)
				OBJECT SET VISIBLE(*; "btn_filter_all-inactive"; False)
				
				OBJECT SET VISIBLE(*; "btn_filter_indoor-active"; False)
				OBJECT SET VISIBLE(*; "btn_filter_indoor-inactive"; True)
				
				OBJECT SET VISIBLE(*; "btn_filter_outdoor-active"; False)
				OBJECT SET VISIBLE(*; "btn_filter_outdoor-inactive"; True)
				
		End case 
	End if 
	
	This._loadVenues()
	
Function _loadVenues()
	var $all : cs.VenueSelection:=ds.Venue.all().orderBy("city ASC, name ASC")
	var $search : Text:=Lowercase(This.searchText)
	var $result : Collection:=[]
	var $venue : cs.VenueEntity
	For each ($venue; $all)
		var $hasIndoor : Boolean:=($venue.indoorOption#Null) && ($venue.indoorOption.name#Null)
		var $hasOutdoor : Boolean:=($venue.outdoorOption#Null) && ($venue.outdoorOption.name#Null)
		// Apply filter
		If (This.activeFilter="indoor") && Not($hasIndoor)
			continue
		End if 
		If (This.activeFilter="outdoor") && Not($hasOutdoor)
			continue
		End if 
		If (This.activeFilter="both") && Not($hasIndoor && $hasOutdoor)
			continue
		End if 
		// Apply search
		If ($search#"")
			If (Position($search; Lowercase($venue.name))=0) && (Position($search; Lowercase($venue.city))=0) && (Position($search; Lowercase($venue.country))=0)
				continue
			End if 
		End if 
		// Format indoor/outdoor strings
		var $indoorStr : Text:=""
		If ($hasIndoor)
			$indoorStr:=$venue._indoorOptionName
			If ($venue.indoorOption.rentalPrice>0)
				$indoorStr:=$indoorStr+" – "+String(Num($venue.indoorOption.rentalPrice); "### ### ##0 €")
			End if 
		End if 
		var $outdoorStr : Text:=""
		If ($hasOutdoor)
			$outdoorStr:=$venue._outdoorOptionName
			If ($venue.outdoorOption.rentalPrice>0)
				$outdoorStr:=$outdoorStr+" – "+String(Num($venue.outdoorOption.rentalPrice); "### ### ##0 €")
			End if 
		End if 
		var $capacity : Integer:=Num($venue.capacity)
		$result.push({\
			name: $venue._name; \
			city: $venue.city; \
			country: $venue.country; \
			indoorStr: $indoorStr; \
			outdoorStr: $outdoorStr; \
			capacityStr: String($capacity)\
			})
	End for each 
	
	var $l10n : Object:={}
	If (True)
		$l10n.venues:=" 施設"
	Else 
		$l10n.venues:=" venues"
	End if 
	
	This.venues:=$result
	OBJECT SET TITLE(*; "text_count"; String($result.length)+$l10n.venues)
	