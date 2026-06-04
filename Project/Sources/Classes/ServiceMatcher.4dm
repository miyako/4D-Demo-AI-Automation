// ServiceMatcher.4dm
// Manages vector embeddings for the Service catalog and semantic search

property _client : Object
property _model : Text

Class constructor()
	This._client:=cs.AIKit.OpenAI.new()
	This._model:="embedding"  // model alias defined in AIProviders.json

// ─── Generates embeddings for all services in the catalog ───────────────────────
// Called once at initial seed
Function buildEmbeddings()
	var $services : cs.ServiceSelection:=ds.Service.query("embedding = null")
	var $service : cs.ServiceEntity
	var $count : Integer:=0

	For each ($service; $services)
		var $desc : Text:=$service.description || $service.label
		var $text : Text:=$service.category+" | "+$service.label+" | "+$service.unit+" | "+$desc
		var $result : Object:=This._client.embeddings.create($text; This._model)
		If ($result.vector#Null)
			$service.embedding:=$result.vector
			$service.save()
			$count:=$count+1
		End if 
	End for each 

// ─── Forces recalculation of all embeddings (after label changes) ──────────────
Function rebuildAllEmbeddings()
	var $services : cs.ServiceSelection:=ds.Service.all()
	var $service : cs.ServiceEntity

	For each ($service; $services)
		var $desc : Text:=$service.description || $service.label
		var $text : Text:=$service.category+" | "+$service.label+" | "+$service.unit+" | "+$desc
		var $result : Object:=This._client.embeddings.create($text; This._model)
		If ($result.vector#Null)
			$service.embedding:=$result.vector
			$service.save()
		End if 
	End for each 

// ─── Semantic search in the catalog ────────────────────────────────────────────
// Returns the top services matching the query (max $limit results)
Function search($query : Text; $category : Text; $limit : Integer) : Collection
	If ($limit=0)
		$limit:=5
	End if 

	// Create the query embedding
	var $searchText : Text:=$query
	If ($category#"")
		$searchText:=$category+" | "+$searchText
	End if 
	var $result : Object:=This._client.embeddings.create($searchText; This._model)
	If ($result.vector=Null)
		// Fallback to keyword search if embedding fails
		return This._keywordSearch($query; $category; $limit)
	End if 

	var $vec : 4D.Vector:=$result.vector

	// Recherche vectorielle ORDA — try progressively looser thresholds
	var $found : cs.ServiceSelection
	var $thresholds : Collection:=[0.3; 0.2; 0.15]
	var $t : Real
	For each ($t; $thresholds)
		var $comparisonVector : Object:={vector: $vec; metric: mk cosine; threshold: $t}
		If ($category#"")
			$found:=ds.Service.query("embedding > :1 AND category = :2 AND available = true"; $comparisonVector; $category)
		Else 
			$found:=ds.Service.query("embedding > :1 AND available = true"; $comparisonVector)
		End if 
		If ($found.length>0)
			break
		End if 
	End for each 

	// If semantic search still empty, fallback to keyword search
	If ($found=Null) || ($found.length=0)
		return This._keywordSearch($query; $category; $limit)
	End if 

	// Build the result collection
	var $results : Collection:=[]
	var $svc : cs.ServiceEntity
	var $i : Integer:=0
	For each ($svc; $found)
		If ($i<$limit)
			$results.push({ \
				serviceID: $svc.ID; \
				label: $svc.label; \
				category: $svc.category; \
				unitPrice: $svc.unitPrice; \
				unit: $svc.unit \
			})
			$i:=$i+1
		End if 
	End for each 

	return $results

// ─── Fallback keyword search (used when vector search returns nothing) ────────
Function _keywordSearch($query : Text; $category : Text; $limit : Integer) : Collection
	// Extract meaningful words from query (drop stop words and numbers)
	var $stopWords : Collection:=["for"; "a"; "an"; "the"; "of"; "to"; "with"; "and"; "or"; "in"; "on"; "at"; "by"; "from"; "per"; "x"; "guests"; "pax"; "units"; "pack"; "packs"; "set"; "sets"]
	var $words : Collection:=Split string(Lowercase($query); " ")
	var $keywords : Collection:=[]
	var $w : Text
	For each ($w; $words)
		// Strip punctuation and digits-only tokens
		$w:=Replace string($w; "("; "")
		$w:=Replace string($w; ")"; "")
		$w:=Replace string($w; ","; "")
		If ((Length($w)>2) && ($stopWords.indexOf($w)<0) && (Num($w)=0))
			$keywords.push($w)
		End if 
	End for each 

	If ($keywords.length=0)
		return []
	End if 

	// Search each keyword against label, collect union of results
	var $seen : Object:={}
	var $results : Collection:=[]
	var $kw : Text
	var $qry : Text
	var $hits : cs.ServiceSelection
	For each ($kw; $keywords)
		If ($category#"")
			$qry:="label = :1 AND category = :2 AND available = true"
			$hits:=ds.Service.query($qry; "@"+$kw+"@"; $category)
		Else 
			$qry:="label = :1 AND available = true"
			$hits:=ds.Service.query($qry; "@"+$kw+"@")
		End if 
		var $hit : cs.ServiceEntity
		For each ($hit; $hits)
			If ($seen[String($hit.ID)]=Null) && ($results.length<$limit)
				$seen[String($hit.ID)]:=True
				$results.push({ \
					serviceID: $hit.ID; \
					label: $hit.label; \
					category: $hit.category; \
					unitPrice: $hit.unitPrice; \
					unit: $hit.unit \
				})
			End if 
		End for each 
	End for each 

	return $results
