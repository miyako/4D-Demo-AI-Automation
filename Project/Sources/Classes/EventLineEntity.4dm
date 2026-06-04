// EventLineEntity.4dm — Computed attributes for the EventLine entity

Class extends Entity

Function get serviceLabel() : Text
	var $s : cs.ServiceEntity:=This.service
	return $s ? $s.label : "—"

Function get serviceCategory() : Text
	var $s : cs.ServiceEntity:=This.service
	return $s ? $s.category : "—"

Function get quantityStr() : Text
	return String(This.quantity)

Function get unitPriceStr() : Text
	return String(This.unitPrice; "### ### ##0 €")

Function get totalStr() : Text
	return String(This.quantity*This.unitPrice; "### ### ##0 €")

Function get lineTotal() : Real
	return This.quantity*This.unitPrice
