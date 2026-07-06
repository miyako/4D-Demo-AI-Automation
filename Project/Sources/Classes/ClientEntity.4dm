Class extends Entity

Function get _companyName() : Text
	
	var $o : Object
	$o:=This._split(This.companyName)
	
	If ($o.success)
		return $o.text
	Else 
		return This.companyName
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