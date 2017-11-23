push-location "$BuildToolsPath\Logging"
. .\LoggingFunctions.ps1
pop-location

Import-Module WebAdministration
#Go to the IIS directory
Set-Location "IIS:\AppPools"

foreach ($AppPool_Name in $Windows_AppPool_Name.Split('|'))

# Verify AppPool_Name Variable Value is not null or empty 

{
 if ([String]::IsNullorEmpty($AppPool_Name))

 {
  log-info " '$AppPool_Name'  AppPool Name is NULL or EMPTY `n"
 }

else

# Verify AppPool_Name exists or not.

{
 if (Test-Path $AppPool_Name)
   
  {
   log-info " '$AppPool_Name' IIS AppPool does exists `n"

   $AppPool_Service=$AppPool_Service_Action
   
   $appsrvc = Get-WebItemState "$AppPool_Name"

   if($AppPool_Service -eq 'Start')
    {

     if($appsrvc.Value -ne "Started")
      {

       log-info "Starting stopped AppPool '$AppPool_Name'....`n"
       
       Start-WebAppPool -Name $AppPool_Name

		log-info "`n '$AppPool_Name' Started Successfully. `n"
      }
	  else
	  {
		log-info "`n '$AppPool_Name' is already started. `n"
	  }
    }

  if($AppPool_Service -eq 'Stop')
    {

     if($appsrvc.Value -ne "Stopped")
      {

       log-info "Stopping AppPool '$AppPool_Name'....`n"
       
       Stop-WebAppPool -Name $AppPool_Name
	   
	   log-info "'$AppPool_Name' Stopped Successfully. `n"

      }
   
    } 
	else
	{
		log-info "'$AppPool_Name' is already stopped."
	}
    
   if($AppPool_Service -ne 'Start' -and $AppPool_Service -ne 'Stop')
       
    {
      log-info "'$AppPool_Service' is not a valid IIS AppPool Action! `n"
    }
    
   }
   
  else
   
   {
    log-info "IIS AppPool Name on this name '$AppPool_Name' doesn't exist. `n"
   }
    
  }
  
}
