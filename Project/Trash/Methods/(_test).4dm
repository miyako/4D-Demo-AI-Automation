//%attributes = {}
$services:=ds.Service.all()

For each ($service; $services)
	$service.label:=Replace string($service.label; "&amp;"; "&"; *)
	$service.save()
End for each 