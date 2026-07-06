Class extends Entity

Function get _category() : Text
	
	Case of 
		: (This.category="Accommodation")
			return "宿泊"
		: (This.category="Catering")
			return "飲食"
		: (This.category="Communication")
			return "受付"
		: (This.category="Coordination")
			return "企画"
		: (This.category="Entertainment")
			return "娯楽"
		: (This.category="Furniture & Decor")
			return "家具•装飾"
		: (This.category="Health & Safety")
			return "保健•安全"
		: (This.category="Lighting")
			return "照明"
		: (This.category="Photography & Film")
			return "写真•動画"
		: (This.category="Security")
			return "警備"
		: (This.category="Sound & AV")
			return "音響•映像"
		: (This.category="Structure")
			return "構造•設営"
		: (This.category="Technical")
			return "技術"
		: (This.category="Transport")
			return "運搬"
		: (This.category="Venue")
			return "会場"
	End case 
	
	return This.category