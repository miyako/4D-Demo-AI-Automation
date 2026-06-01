// ServiceMatcher.4dm
// Gère les embeddings vectoriels du catalogue Service et la recherche sémantique

property _client : Object
property _model : Text

Class constructor()
	This._client:=cs.AIKit.OpenAI.new()
	This._model:="embedding"  // model alias défini dans AIProviders.json

// ─── Génère les embeddings pour tous les services du catalogue ────────────────
// Appelé une seule fois au seed initial
Function buildEmbeddings()
	var $services : cs.ServiceSelection:=ds.Service.query("embedding = null")
	var $service : cs.ServiceEntity
	var $count : Integer:=0

	For each ($service; $services)
		var $text : Text:=$service.category+" | "+$service.label+" | "+$service.unit
		var $result : Object:=This._client.embeddings.create($text; This._model)
		If ($result.vector#Null)
			$service.embedding:=$result.vector
			$service.save()
			$count:=$count+1
		End if 
	End for each 

// ─── Force la recalcul de tous les embeddings (après changement de labels) ────
Function rebuildAllEmbeddings()
	var $services : cs.ServiceSelection:=ds.Service.all()
	var $service : cs.ServiceEntity

	For each ($service; $services)
		var $text : Text:=$service.category+" | "+$service.label+" | "+$service.unit
		var $result : Object:=This._client.embeddings.create($text; This._model)
		If ($result.vector#Null)
			$service.embedding:=$result.vector
			$service.save()
		End if 
	End for each 

// ─── Recherche sémantique dans le catalogue ──────────────────────────────────
// Retourne les top services matchant la query (max $limit résultats)
Function search($query : Text; $category : Text; $limit : Integer) : Collection
	If ($limit=0)
		$limit:=5
	End if 

	// Créer l'embedding de la requête
	var $searchText : Text:=$query
	If ($category#"")
		$searchText:=$category+" | "+$searchText
	End if 
	var $result : Object:=This._client.embeddings.create($searchText; This._model)
	If ($result.vector=Null)
		return []
	End if 

	var $vec : 4D.Vector:=$result.vector

	// Recherche vectorielle ORDA
	var $comparisonVector : Object:={vector: $vec; metric: mk cosine; threshold: 0.3}
	var $found : cs.ServiceSelection

	If ($category#"")
		$found:=ds.Service.query("embedding > :1 AND category = :2 AND available = true"; $comparisonVector; $category)
	Else 
		$found:=ds.Service.query("embedding > :1 AND available = true"; $comparisonVector)
	End if 

	// Construire la collection de résultats
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
