// FC_VenueBrowser.4dm
// Read-only browser for venues with indoor/outdoor options and rental pricing

property venues : Collection
property activeFilter : Text
property searchText : Text

Class constructor()
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
		: ($formEventCode=On Data Change)
			This.searchText:=OBJECT Get value("input_search")
			This._loadVenues()
	End case 

//MARK: - Private
Function _onLoad()
	This._loadVenues()

Function _setFilter($filter : Text)
	This.activeFilter:=$filter
	OBJECT SET STYLE SHEET(*; "btn_filter_all"; Choose($filter="all"; "btnFilterActive"; "btnFilterInactive"))
	OBJECT SET STYLE SHEET(*; "btn_filter_both"; Choose($filter="both"; "btnFilterActive"; "btnFilterInactive"))
	OBJECT SET STYLE SHEET(*; "btn_filter_indoor"; Choose($filter="indoor"; "btnFilterActive"; "btnFilterInactive"))
	OBJECT SET STYLE SHEET(*; "btn_filter_outdoor"; Choose($filter="outdoor"; "btnFilterActive"; "btnFilterInactive"))
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
			$indoorStr:=$venue.indoorOption.name
			If ($venue.indoorOption.rentalPrice>0)
				$indoorStr:=$indoorStr+" – "+String(Num($venue.indoorOption.rentalPrice); "### ### ##0 €")
			End if 
		End if 
		var $outdoorStr : Text:=""
		If ($hasOutdoor)
			$outdoorStr:=$venue.outdoorOption.name
			If ($venue.outdoorOption.rentalPrice>0)
				$outdoorStr:=$outdoorStr+" – "+String(Num($venue.outdoorOption.rentalPrice); "### ### ##0 €")
			End if 
		End if 
		var $capacity : Integer:=Num($venue.capacity)
		$result.push({ \
			name: $venue.name; \
			city: $venue.city; \
			country: $venue.country; \
			indoorStr: $indoorStr; \
			outdoorStr: $outdoorStr; \
			capacityStr: String($capacity) \
		})
	End for each 

	This.venues:=$result
	OBJECT SET TITLE(*; "text_count"; String($result.length)+" venues")
