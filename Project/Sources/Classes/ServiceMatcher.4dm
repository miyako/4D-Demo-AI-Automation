// ServiceMatcher.4dm
// Manages vector embeddings for the Service catalog and semantic search

property _client : Object
property _model : Text

Class constructor()
	This._client:=cs.AIKit.OpenAI.new()
	This._model:="embedding-local"  // model alias defined in AIProviders.json
	
	// ─── Generates embeddings for services missing one ──────────────────────────
Function buildEmbeddings()
	This._computeEmbeddings(ds.Service.query("embedding = null"))
	
	// ─── Recomputes all embeddings (after label/description changes) ────────────
Function rebuildAllEmbeddings()
	This._computeEmbeddings(ds.Service.all())
	
	// ─── Shared embedding computation loop ────────────────────────────────────────
Function _computeEmbeddings($services : cs.ServiceSelection)
	var $service : cs.ServiceEntity
	var $batch : Object
	var $i; $length : Integer
	$i:=0
	$length:=16  //records per batch
	var $entities : cs.EntitySelection
	$entities:=$services.slice($i; $i+$length)
	While ($entities.length#0)
		var $text : Collection
		$text:=[]
		var $entity : cs.Entity
		For each ($entity; $entities)
			var $desc : Text:=$entity.description || $entity.label
			$text.push($entity.category+" | "+$entity.label+" | "+$entity.unit+" | "+$desc)
		End for each 
		$batch:=This._client.embeddings.create($text; This._model)
		If ($batch.success)
			$embeddings:=$batch.embeddings
			For each ($entity; $entities)
				$entity.embedding:=$embeddings.shift().embedding
				$entity.save()
			End for each 
		End if 
		$i+=$length
		$entities:=$services.slice($i; $i+$length)
	End while 
	
	// ─── Semantic search in the catalog ────────────────────────────────────────────
	// Returns the top services matching the query (max $limit results)
Function search($query : Text; $category : Text; $limit : Integer) : Collection
	If ($limit=0)
		$limit:=5
	End if 
	
	// Create the query embedding prepend category to steer the vector
	var $searchText : Text:=($category#"") ? ($category+" | "+$query) : $query
	var $result : Object:=This._client.embeddings.create($searchText; This._model)
	If ($result.vector=Null)
		// Fallback to keyword search if embedding fails
		return This._keywordSearch($query; $category; $limit)
	End if 
	
	var $vec : 4D.Vector:=$result.vector
	
	// Semantic vector search strict threshold; sort by similarity so best matches come first
	var $found : cs.ServiceSelection
	var $comparisonVector : Object:={vector: $vec; metric: mk cosine; threshold: 0.3}
	If ($category#"")
		$found:=ds.Service.query("embedding > :1 AND category = :2 AND available = true order by embedding desc"; $comparisonVector; $category)
	Else 
		$found:=ds.Service.query("embedding > :1 AND available = true order by embedding desc"; $comparisonVector)
	End if 
	
	// If semantic search returns nothing, fall back to keyword search
	If ($found=Null) || ($found.length=0)
		return This._keywordSearch($query; $category; $limit)
	End if 
	
	return This._toResults($found; $limit)
	
	// ─── Fallback keyword search (used when vector search returns nothing) ────────
Function _keywordSearch($query : Text; $category : Text; $limit : Integer) : Collection
	// Extract meaningful words from query (drop stop words and short tokens)
	var $stopWords : Collection:=["for"; "a"; "an"; "the"; "of"; "to"; "with"; "and"; "or"; "in"; "on"; "at"; "by"; "from"; "per"; "x"; "guests"; "pax"; "units"; "pack"; "packs"; "set"; "sets"]
	var $words : Collection:=Split string(Lowercase($query); " ")
	var $keywords : Collection:=[]
	var $w : Text
	For each ($w; $words)
		$w:=Replace string(Replace string(Replace string($w; "("; ""); ")"; ""); ","; "")
		If ((Length($w)>2) && ($stopWords.indexOf($w)<0) && (Num($w)=0))
			$keywords.push($w)
		End if 
	End for each 
	
	If ($keywords.length=0)
		return []
	End if 
	
	// Union all keyword hits into a single deduplicated entity selection via .or()
	var $allHits : cs.ServiceSelection:=ds.Service.newSelection()
	var $kw : Text
	For each ($kw; $keywords)
		var $hits : cs.ServiceSelection
		If ($category#"")
			$hits:=ds.Service.query("label = :1 AND category = :2 AND available = true"; "@"+$kw+"@"; $category)
		Else 
			$hits:=ds.Service.query("label = :1 AND available = true"; "@"+$kw+"@")
		End if 
		$allHits:=$allHits.or($hits)
	End for each 
	
	return This._toResults($allHits; $limit)
	
	// ─── Converts a ServiceSelection to the standard result collection format ─────
	// Uses toCollection for efficient bulk extraction, then renames ID → serviceID
Function _toResults($sel : cs.ServiceSelection; $limit : Integer) : Collection
	var $raw : Collection:=$sel.toCollection("ID, label, category, unitPrice, unit"; 0; 0; $limit)
	var $results : Collection:=[]
	var $item : Object
	For each ($item; $raw)
		$item.serviceID:=$item.ID
		OB REMOVE($item; "ID")
		$results.push($item)
	End for each 
	return $results
	