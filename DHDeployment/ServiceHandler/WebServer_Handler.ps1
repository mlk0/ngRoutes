push-location "$BuildToolsPath\Logging"
. .\LoggingFunctions.ps1
pop-location

$arrService = Get-Service -Name "WAS"
$IIS_Action=$OctopusParameters['IIS_Server_Action']
if($IIS_Action -eq 'Start')
{
if($arrService.Status -ne "Running")
 {
    $reset_output = $(iisreset /noforce)
	if ( $reset_output -match "successfully restarted" ) {
		log-info "Sucessfully restarted Webserver"
	} else {
{
		log-info "Webserver Restart failed"
	Notify "$reset_output"
	exit 1
	}
}
}
}
if($IIS_Action -eq 'Stop')
{
if($arrService.Status -ne "Stopped")
 {
    $reset_output = $(iisreset /stop)
	if ( $reset_output -match "successfully stopped" ) {
		log-info "Sucessfully stopped Webserver"
	} else {
{
		log-info "Webserver stopping failed"
	Notify "$reset_output"
	exit 1
	}
}
}
}