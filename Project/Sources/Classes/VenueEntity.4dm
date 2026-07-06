Class extends Entity

Function get _indoorOptionName() : Text
	
	If (This.indoorOption=Null) || (Value type(This.indoorOption.name)#Is text)
		return 
	End if 
	
	var $o : Object
	$o:=This._split(This.indoorOption.name)
	
	If ($o.success)
		return $o.text
	Else 
		return This.indoorOption.name
	End if 
	
Function get _outdoorOptionName() : Text
	
	If (This.outdoorOption=Null) || (Value type(This.outdoorOption.name)#Is text)
		return 
	End if 
	
	var $o : Object
	$o:=This._split(This.outdoorOption.name)
	
	If ($o.success)
		return $o.text
	Else 
		return This.outdoorOption.name
	End if 
	
Function get _address() : Text
	
	var $o : Object
	$o:=This._split(This.address)
	
	If ($o.success)
		return $o.text
	Else 
		return This.address
	End if 
	
Function get _name() : Text
	
	var $o : Object
	$o:=This._split(This.name)
	
	If ($o.success)
		return $o.text
	Else 
		return This.name
	End if 
	
Function _split($t : Text) : Object
	
	ARRAY LONGINT($pos; 0)
	ARRAY LONGINT($len; 0)
	
	If (Match regex("(.+)\\s*\\(([^)]+)\\)"; $t; 1; $pos; $len))
		var $j; $e; $text : Text
		$j:=Substring($t; $pos{1}; $len{1})
		$e:=Substring($t; $pos{2}; $len{2})
		$text:=$j+"\r"+$e
		return {text: $text; success: True}
	End if 
	
	return {success: False}