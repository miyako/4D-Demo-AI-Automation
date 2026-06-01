// FC_DemoSendEmail.4dm
// Simulateur d'envoi d'email — injecte un email de démo dans la base puis ouvre EmailDetail

property sender : Text
property senderEmail : Text
property subject : Text
property body : Text
property emailType : Text

Class constructor()
	This.sender:=""
	This.senderEmail:=""
	This.subject:=""
	This.body:=""
	This.emailType:="quote"

//MARK: - Form & form objects event handlers
Function formEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Load)
			This._onLoad()
	End case 

Function btnTplQuoteEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._applyTemplate("quote")
	End case 

Function btnTplModificationEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._applyTemplate("modification")
	End case 

Function btnTplAmbiguousEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._applyTemplate("ambiguous")
	End case 

Function btnSendEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			This._send()
	End case 

Function btnCancelEventHandler($formEventCode : Integer)
	Case of 
		: ($formEventCode=On Clicked)
			CANCEL
	End case 

//MARK: - Private
Function _onLoad()
	This._applyTemplate("quote")

Function _applyTemplate($template : Text)
	Case of 
		: ($template="quote")
			This.sender:="Emma Richards"
			This.senderEmail:="emma.r@stratospheregroup.co.uk"
			This.subject:="Gala dinner enquiry – London – November 2026"
			This.body:="Good morning,\n\nStratosphere Group is planning a gala dinner for 280 guests at a prestigious London venue, ideally near the Thames. The event is tentatively scheduled for November 14, 2026.\n\nWe'd need:\n- Seated 4-course dinner with wine pairing\n- A jazz quartet for background music\n- Professional photographer\n- Elegant floral arrangements\n\nBudget is around £45,000. Could you send us a proposal?\n\nKind regards,\nEmma Richards\nHead of Events, Stratosphere Group"
			This.emailType:="quote"

		: ($template="modification")
			var $clients : cs.ClientSelection:=ds.Client.all()
			var $refClient : cs.ClientEntity
			var $refEvent : cs.EventEntity
			If ($clients.length>0)
				$refClient:=$clients[0]
				var $events : cs.EventSelection:=ds.Event.query("clientID = :1 AND status = :2"; $refClient.ID; "confirmed").orderBy("eventDate ASC")
				If ($events.length>0)
					$refEvent:=$events.first()
				End if 
			End if 

			This.sender:=Choose($refClient#Null; $refClient.contactName; "Alice Martin")
			This.senderEmail:=Choose($refClient#Null; $refClient.email; "a.martin@demo.com")
			This.subject:="Modification – "+Choose($refEvent#Null; $refEvent.contractRef; "CTR-2026-100")+" – additional AV request"
			This.body:="Hello,\n\nRegarding our upcoming event ("+Choose($refEvent#Null; $refEvent.contractRef; "CTR-2026-100")+"), we would like to add the following:\n\n- A 3m x 2m LED video wall behind the main stage\n- 2 wireless handheld microphones for the panel discussion\n- 1 confidence monitor for the speaker\n\nCould you update the quote and let us know the additional cost?\n\nThank you,\n"+Choose($refClient#Null; $refClient.contactName; "Alice Martin")
			This.emailType:="modification"

		: ($template="ambiguous")
			This.sender:="Pierre Dubois"
			This.senderEmail:="p.dubois@ambiguous-corp.fr"
			This.subject:="Ajout photographe – événement à venir"
			This.body:="Bonjour,\n\nPour notre prochain événement, nous souhaitons ajouter un service de photographie avec un album premium (100 pages).\n\nPouvez-vous nous dire si c'est disponible et à quel prix ?\n\nCordialement,\nPierre Dubois"
			This.emailType:="modification"
	End case 

	OBJECT SET VALUE("input_from"; This.sender)
	OBJECT SET VALUE("input_email"; This.senderEmail)
	OBJECT SET VALUE("input_subject"; This.subject)
	OBJECT SET VALUE("input_body"; This.body)

Function _send()
	This.sender:=OBJECT Get value("input_from")
	This.senderEmail:=OBJECT Get value("input_email")
	This.subject:=OBJECT Get value("input_subject")
	This.body:=OBJECT Get value("input_body")

	If ((This.subject="") || (This.body=""))
		ALERT("Subject and body are required.")
		return 
	End if 

	var $bodyLow : Text:=Lowercase(This.body)
	If ((Position("quote"; $bodyLow)>0) || (Position("proposal"; $bodyLow)>0) || (Position("devis"; $bodyLow)>0))
		This.emailType:="quote"
	Else 
		If ((Position("modification"; $bodyLow)>0) || (Position("add"; $bodyLow)>0) || (Position("ajouter"; $bodyLow)>0) || (Position("update the quote"; $bodyLow)>0))
			This.emailType:="modification"
		Else 
			This.emailType:="info"
		End if 
	End if 

	var $email : cs.EmailEntity:=ds.Email.new()
	$email.sender:=This.sender
	$email.senderEmail:=This.senderEmail
	$email.subject:=This.subject
	$email.body:=This.body
	$email.receivedAt:=Current date
	$email.emailStatus:="unread"
	$email.emailType:=This.emailType
	$email.linkedEventID:=""
	$email.save()

	var $fc : cs.FC_EmailDetail:=cs.FC_EmailDetail.new($email; Null)
	var $w : Integer:=Open form window("EmailDetail"; Plain form window)
	DIALOG("EmailDetail"; $fc)
	CLOSE WINDOW($w)

	CANCEL
