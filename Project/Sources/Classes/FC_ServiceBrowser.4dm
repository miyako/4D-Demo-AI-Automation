// FC_ServiceBrowser.4dm
// Read-only browser for the services catalog

property services : Collection
property activeCategory : Text
property searchText : Text

Class constructor()
	This.services:=[]
	This.activeCategory:="all"
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
			This._setCategory("all")
	End case 

Function btnFilterCateringEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setCategory("Catering")
	End case 

Function btnFilterSoundEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setCategory("Sound & AV")
	End case 

Function btnFilterStructuresEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setCategory("Structures")
	End case 

Function btnFilterDecorEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setCategory("Furniture & Decor")
	End case 

Function inputSearchEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Data Change)
			This.searchText:=OBJECT Get value("input_search")
			This._loadServices()
	End case 

//MARK: - Private
Function _onLoad()
	This._loadServices()

Function _setCategory($cat : Text)
	This.activeCategory:=$cat
	This._loadServices()

Function _loadServices()
	var $all : cs.ServiceSelection
	If (This.activeCategory="all")
		$all:=ds.Service.all().orderBy("category ASC, label ASC")
	Else 
		$all:=ds.Service.query("category = :1"; This.activeCategory).orderBy("label ASC")
	End if 

	var $search : Text:=Lowercase(This.searchText)
	var $result : Collection:=[]
	var $svc : cs.ServiceEntity
	For each ($svc; $all)
		If (($search="") || (Position($search; Lowercase($svc.label))>0) || (Position($search; Lowercase($svc.category))>0))
			$result.push({ \
				label: $svc.label; \
				category: $svc.category; \
				unit: $svc.unit; \
				unitPriceStr: String($svc.unitPrice; "### ### ##0 €"); \
				availableIcon: Choose($svc.available; "✓"; "–") \
			})
		End if 
	End for each 

	This.services:=$result
	OBJECT SET TITLE(*; "text_count"; String($result.length)+" services")
