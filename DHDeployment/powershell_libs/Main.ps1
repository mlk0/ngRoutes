# Start of Main.ps1
#Load library of functions
. .\IIS_lib.ps1

#Set global variables  
$ConfigPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition      
$Global:logPath = $ConfigPath+'\logfile.log'                   

Try { 
            Clear-Host

            $xmlinfo = Datadeclaration $ConfigPath\config

            CreateAppPool $xmlinfo.siteApppoolName $xmlinfo
            
            CreateSite $xmlinfo
            
            CreateApplication $xmlinfo
    }      
 Catch [System.Exception]{
         
            Write-Host $_.Exception.Message -ForegroundColor Green  

            If((Test-Path -path $Global:logPath))
            {
                add-content -Path $Global:logPath -Value "$((Get-Date).ToString("yyyy MM dd hh:mm:ss"))  :  Error  -  $($_.Exception.Message)"
            }     
     }
Finally{
        
            Write-Host "---------------------------------"  -ForegroundColor White
        
            If((Test-Path -path $Global:logPath))
            {
                add-content -Path $Global:logPath -Value "------------------------------------------------------------------------"  
            }
            Read-Host 
        }
           
#----------------------------------

