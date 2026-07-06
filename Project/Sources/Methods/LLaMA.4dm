//%attributes = {"invisible":true}
var $llama : cs.llama.llama

var $homeFolder : 4D.Folder
$homeFolder:=Folder(fk home folder).folder(".GGUF")

var $file : 4D.File
var $URL : Text
var $port : Integer
var $huggingface : cs.event.huggingface

var $event : cs.event.event
$event:=cs.event.event.new()

$event.onError:=Formula(ALERT($2.message))
$event.onSuccess:=Formula(ALERT($2.models.extract("name").join(",")+" loaded!"))
$event.onData:=Formula(LOG EVENT(Into 4D debug message; This.file.fullName+":"+String((This.range.end/This.range.length)*100; "###.00%")))
$event.onResponse:=Formula(LOG EVENT(Into 4D debug message; This.file.fullName+":download complete"))
$event.onTerminate:=Formula(LOG EVENT(Into 4D debug message; (["process"; $1.pid; "terminated!"].join(" "))))

$port:=8888

var $folder : 4D.Folder
$folder:=$homeFolder.folder("llama-"+String($port))

var $iniFile : 4D.File
var $ini : Collection

$ini:=[]
$ini.push("version = 1")

$ini.push("[*]")
$ini.push("n-gpu-layers = 999")

$ini.push("[bge-m3]")
$ini.push("model = "+$homeFolder.file("bge-m3/bge-m3-Q8_0.gguf").path)
$ini.push("pooling = cls")
$ini.push("embedding = true")
var $max_position_embeddings; $batches; $batch_size; $ubatch_size; $threads; $threads_batch : Integer
$max_position_embeddings:=512
$batch_size:=$max_position_embeddings
$ubatch_size:=$max_position_embeddings
$batches:=16
$threads:=$batches
$threads_batch:=1
$ini.push("ctx-size = "+String($max_position_embeddings*$batches))
$ini.push("load-on-startup = true")
$ini.push("batch-size = "+String($batch_size*$batches))
$ini.push("ubatch-size = "+String($ubatch_size))
$ini.push("parallel = "+String($batches))
$ini.push("threads = "+String($threads))
$ini.push("threads-batch = "+String($threads_batch))
$ini.push("threads-http = "+String($batches+1))

$iniFile:=$folder.file("models.ini")
$iniFile.setText($ini.join("\n"))

$logFile:=$folder.file("llama.log")
$folder.create()
If (Not($logFile.exists))
	$logFile.setContent(4D.Blob.new())
End if 

$options:={models_preset: $iniFile; log_file: $logFile; log_disable: False}

$llama:=cs.llama.llama.new($port; Null; $homeFolder; $options; $event)

If (False)
	
	$port:=8081
	
	$folder:=$homeFolder.folder("gemma-4")
	$path:="gemma-4-E4B-it-Q4_K_M.gguf"
	$URL:="unsloth/gemma-4-E4B-it-GGUF"
	$cache_type_k:="q4_0"
	$cache_type_v:="q4_0"
	$n_gpu_layers:=99
	$threads:=6
	$batches:=1
	$ubatch_size:=512
	$batch_size:=2048
	$max_position_embeddings:=8192
	
	var $logFile : 4D.File
	$logFile:=$folder.file("llama.log")
	$folder.create()
	If (Not($logFile.exists))
		$logFile.setContent(4D.Blob.new())
	End if 
	
	var $options : Object
	
	$options:={\
		ctx_size: $max_position_embeddings*$batches; \
		batch_size: $batch_size; \
		ubatch_size: $ubatch_size; \
		parallel: $batches; \
		threads: $threads; \
		threads_batch: $threads; \
		threads_http: 2; \
		temp: 1; \
		min_p: 0; \
		top_k: 20; \
		top_p: 0.95; \
		repeat_penalty: 1; \
		presence_penalty: 0; \
		n_gpu_layers: $n_gpu_layers; \
		log_disable: False; \
		log_file: $logFile; \
		jinja: True}
	
	var $huggingfaces : cs.event.huggingfaces
	
	$huggingface:=cs.event.huggingface.new($folder; $URL; [$path; $assistant; $mmproj])
	$huggingfaces:=cs.event.huggingfaces.new([$huggingface])
	
	$llama:=cs.llama.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
	
End if 