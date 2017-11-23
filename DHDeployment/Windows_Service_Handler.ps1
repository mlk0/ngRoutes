push-location "$BuildToolsPath\Logging"
. .\LoggingFunctions.ps1
pop-location

foreach ($Service_Name in $Windows_Service_Name.Split('|'))

# Verify Windows Service Variable Value is not null or empty 

{
 if ([String]::IsNullorEmpty($Service_Name))

 {
  log-info "`n '$Service_Name' Service Name is NULL or EMPTY `n"
 }

else

# Verify Windows Service Name exists or not.

{
 if (Get-Service | Where-Object {$_.DisplayName -eq $Service_Name -or $_.Name -eq $Service_Name})
   
  {
   log-info "`n '$Service_Name' Windows Service does exists `n"


   $arrService = Get-Service -Name $Service_Name

   $Windows_Service=$Windows_Service_Action

   if($Windows_Service -eq 'Start')
    {

     if($arrService.Status -ne "Running")
      {

       log-info "Starting stopped service '$Service_Name'....`n '$Service_Name' Started Successfully. `n"
       
       Start-Service -Name $Service_Name

      }
    }

  if($Windows_Service -eq 'Stop')
    {

     if($arrService.Status -ne "Stopped")
      {

       log-info "Stopping service '$Service_Name'....`n '$Service_Name' Stopped Successfully. `n"
       
       Stop-Service -Name $Service_Name

      }
   
    }
    
   if($Windows_Service -ne 'Start' -and $Windows_Service -ne 'Stop')
       
    {
      log-info "'$Windows_Service' is not a valid Windows Service Action! `n"
    }
    
   }
   
  else
   
   {
    log-info "Windows Service Name on this name '$Service_Name' doesn't exist. `n"
   }
    
  }
  
}
