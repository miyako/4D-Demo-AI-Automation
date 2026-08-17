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
//$event.onSuccess:=Formula(ALERT($2.models.extract("name").join(",")+" loaded!"))
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

var $logFile : 4D.File
$logFile:=$folder.file("llama.log")
$folder.create()
If (Not($logFile.exists))
	$logFile.setContent(4D.Blob.new())
End if 

var $options : Object
$options:={models_preset: $iniFile; log_file: $logFile; log_disable: False}

$llama:=cs.llama.llama.new($port; Null; $homeFolder; $options; $event)