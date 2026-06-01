// FC_EmailInbox.4dm
// Liste des emails avec badge de type et filtre

property emails : Collection
property activeFilter : Text
property currentEmail : Object

Class constructor()
	This.emails:=[]
	This.activeFilter:="all"
	This.currentEmail:=Null

//MARK: - Form & form objects event handlers
Function formEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Load)
			This._onLoad()
		: ($formEventCode=On Double Clicked)
			This._onDoubleClicked()
	End case 

Function btnFilterAllEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("all")
	End case 

Function btnFilterUnreadEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("unread")
	End case 

Function btnFilterQuoteEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("quote")
	End case 

Function btnFilterModifEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("modification")
	End case 

Function btnFilterInfoEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._setFilter("info")
	End case 

//MARK: - Private
Function _onLoad()
	This._loadEmails("all")

Function _onDoubleClicked()
	If (This.currentEmail#Null)
		var $email : cs.EmailEntity:=ds.Email.get(This.currentEmail.id)
		If ($email#Null)
			$email.emailStatus:="read"
			$email.save()
			var $emailIDs : Collection:=This.emails.extract("id")
			var $fc : cs.FC_EmailDetail:=cs.FC_EmailDetail.new($email; $emailIDs)
			var $w : Integer:=Open form window("EmailDetail"; Plain form window)
			DIALOG("EmailDetail"; $fc)
			CLOSE WINDOW($w)
			This._loadEmails(This.activeFilter)
		End if 
	End if 

Function _setFilter($filter : Text)
	This.activeFilter:=$filter
	This._loadEmails($filter)

Function _loadEmails($filter : Text)
	var $selection : cs.EmailSelection

	Case of 
		: ($filter="unread")
			$selection:=ds.Email.query("emailStatus = :1"; "unread").orderBy("receivedAt DESC")
		: ($filter="quote")
			$selection:=ds.Email.query("emailType = :1"; "quote").orderBy("receivedAt DESC")
		: ($filter="modification")
			$selection:=ds.Email.query("emailType = :1"; "modification").orderBy("receivedAt DESC")
		: ($filter="info")
			$selection:=ds.Email.query("emailType = :1"; "info").orderBy("receivedAt DESC")
		Else 
			$selection:=ds.Email.all().orderBy("receivedAt DESC")
	End case 

	var $unread : Integer:=0
	This.emails:=[]
	var $mail : cs.EmailEntity
	For each ($mail; $selection)
		If ($mail.emailStatus="unread")
			$unread:=$unread+1
		End if 
		This.emails.push({ \
			id: $mail.ID; \
			sender: $mail.sender; \
			senderEmail: $mail.senderEmail; \
			subject: $mail.subject; \
			receivedAtStr: String($mail.receivedAt; Internal date short); \
			emailType: $mail.emailType; \
			emailStatus: $mail.emailStatus; \
			typeBadge: cs.UIHelpers.me.typeBadge($mail.emailType); \
			unreadDot: Choose($mail.emailStatus="unread"; "●"; "") \
		})
	End for each 

	OBJECT SET TITLE(*; "text_unread_count"; String($unread)+" new")
