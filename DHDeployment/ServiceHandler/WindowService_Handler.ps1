push-location "$BuildToolsPath\Logging"
. .\LoggingFunctions.ps1
pop-location

$Service_Name=$OctopusParameters['Windows_Service_Name']
$arrService = Get-Service -Name $Service_Name
$IIS_Action=$OctopusParameters['Windows_Service_Action']
if($IIS_Action -eq 'Start')
{
if($arrService.Status -ne "Running")
 {
  log-info "Starting stopped service $Service_Name ."
   Start-Service -Name $Service_Name

}
}
if($IIS_Action -eq 'Stop')
{
if($arrService.Status -ne "Stopped")
 {
Stop-Service -Name $Service_Name
}
}