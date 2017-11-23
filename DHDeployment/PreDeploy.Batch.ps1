 #####################################################################
 #  Copyright (c) D+H Ltd. 2013
 #
 #  All Rights Reserved
 #
 #  THIS INFORMATION IS COMPANY CONFIDENTIAL
 #
 #  This material is a confidential trade secret and proprietary information of D+H Ltd. which may not be
 #  reproduced, used, sold, or transferred to any third party without the prior written consent of D+H Ltd.
 #
 # ##################################################################

# If there is an error in the script, cause Octopus Deploy to see the error
$ErrorActionPreference = "Stop"
 . ./common_functions.ps1
 
function RobocopyExitCode([int]$exitcode)
{
 $retValue = “UNKNOWN”
 
 switch ($exitcode)
    {
        0 {$retValue = “NO CHANGE”; break}
        1 {$retValue = “COPY”; break}
        2 {$retValue = “EXTRA”; break}
        3 {$retValue = “EXTRA COPY”; break}
        4 {$retValue = “MISMATCH”; break}
        5 {$retValue = “MISMATCH COPY”; break}
        6 {$retValue = “MISMATCH EXTRA”; break}
        7 {$retValue = “MISMATCH EXTRA COPY”; break}
        8 {$retValue = “FAIL”; break}
        9 {$retValue = “FAIL COPY”; break}
        10 {$retValue = “FAIL EXTRA”; break}
        11 {$retValue = “FAIL EXTRA COPY”; break}
        12 {$retValue = “FAIL MISMATCH”; break}
        13 {$retValue = “FAIL MISMATCH COPY”; break}
        14 {$retValue = “FAIL MISMATCH EXTRA”; break}
        15 {$retValue = “FAIL MISMATCH EXTRA COPY”; break}
        16 {$retValue = “FATAL ERROR”; break} 
        default {”UNKNOWN”}
    }
   
    return $retValue
} 
 
try {
	# Load log4net
	push-location "$BuildToolsPath\Logging"
	. .\LoggingFunctions.ps1
	pop-location
    
	log-info "($OctopusEnvironmentName) Web Services deployment for $OctopusProjectName $OctopusReleaseNumber"
	log-info "($OctopusEnvironmentName) Parameters passed in:"
	log-info "($OctopusEnvironmentName) OctopusPackageDirectoryPath $TargetPath"
	log-info "($OctopusEnvironmentName) OctopusOriginalPackageDirectoryPath $OctopusOriginalPackageDirectoryPath"
	log-info "($OctopusEnvironmentName) BuildToolsPath $BuildToolsPath"

} catch {
	write-output "Problem has occurred with the script that may be related to log4net or email setup. Please review Octopus Deploy log."
	throw "Problem has occurred with the script that may be related to log4net or email setup. Please review Octopus Deploy log."
}

try {
    #Stop-Service -Name "MSA-ESA Notifications"
	$folders = "batch","CCCommand","DOBCommand"
    
    # Check existence of target folder
	foreach ($folder in $folders){
    
        
		if (!(Test-Path "$TargetPath\$folder")) {
		  log-info "($OctopusEnvironmentName) The directory $TargetPath\$folder does not exist, creating it."
		  New-Item -ItemType directory -Path $TargetPath\$folder
	   }
       
		if (!(Test-Path "$TargetPath\$folder\eqfx")) {
            log-info "eqfx folder does not exist, therefore creating folder"
            New-Item -ItemType directory -Path "$TargetPath\$folder\eqfx\incoming\Processed"
            New-Item -ItemType directory -Path "$TargetPath\$folder\eqfx\outgoing\Processed"
            New-Item -ItemType directory -Path "$TargetPath\$folder\eqfx\outgoing\QuarterlyReportsToSend"
            New-Item -ItemType directory -Path "$TargetPath\$folder\eqfx\outgoing\WelcomeLettersToSend"
            New-Item -ItemType directory -Path "$TargetPath\$folder\eqfx\outgoing\3MonthMonitor\Processing"
            New-Item -ItemType directory -Path "$TargetPath\$folder\eqfx\outgoing\3MonthMonitor\ToSend"
            New-Item -ItemType directory -Path "$TargetPath\$folder\eqfx\outgoing\CreditReport\Processing"
            New-Item -ItemType directory -Path "$TargetPath\$folder\eqfx\outgoing\CreditReport\ToSend"
        }
    
        if (!(Test-Path "$TargetPath\$folder\IncomingEquifaxFiles")) {
            log-info "IncomingEquifaxFiles folder does not exist, therefore creating folder"
            New-Item -ItemType directory -Path "$TargetPath\$folder\IncomingEquifaxFiles"
        }
        
        
		# Purging target path
		log-info "($OctopusEnvironmentName) Purging $TargetPath\$folder (with some exclusions)."
		Get-ChildItem $TargetPath\$folder -force
		log-info "($OctopusEnvironmentName) Reset Attributes."
		Get-ChildItem $TargetPath\$folder -force -recurse | foreach {$_Attributes = 'Normal'}
		#Purge-TargetPath "$TargetPath\$folder" Not done here as Batch has special requirements/exclusions
        
        
        
        if (Test-Path $TargetPath\$folder\AutoSysScripts\AutoSysBatch.config) {
            Purge-TargetPath "$TargetPath\$folder" -exclude "eqfx","IncomingEquifaxFiles","AutoSysScripts","log" 
            Purge-TargetPath "$TargetPath\$folder\AutoSysScripts" -exclude "AutoSysBatch.config"
            #check purging result
            
            if (((Get-ChildItem $TargetPath\$folder | Measure-Object).Count -eq 3) -and (Test-Path $TargetPath\$folder\eqfx) -and (Test-Path $TargetPath\$folder\IncomingEquifaxFiles) -and (Test-Path $TargetPath\$folder\AutoSysScripts\AutoSysBatch.config)) 
            {
                log-info "($OctopusEnvironmentName) Purging folder $TargetPath\$folder Successful"
             }
             elseif (((Get-ChildItem $TargetPath\$folder | Measure-Object).Count -eq 4) -and (Test-Path $TargetPath\$folder\eqfx) -and (Test-Path $TargetPath\$folder\IncomingEquifaxFiles) -and (Test-Path $TargetPath\$folder\AutoSysScripts\AutoSysBatch.config) -and (Test-Path $TargetPath\$folder\log))
             {
                log-info "($OctopusEnvironmentName) log folder existed inside $TargetPath\$folder"
                log-info "($OctopusEnvironmentName) Purging folder $TargetPath\$folder Successful"
             }
             else {
                if (!(Test-Path $TargetPath\$folder\eqfx)) {log-error "eqfx dne"}
                if (!(Test-Path $TargetPath\$folder\IncomingEquifaxFiles)) {log-error "IncomingEquifaxFiles dne"}
                if (!(Test-Path $TargetPath\$folder\AutoSysScripts\AutoSysBatch.config)) {log-error "AutoSysScripts\AutoSysBatch.config dne"}
                log-error "($OctopusEnvironmentName) Purging folder $TargetPath\$folder failed"
                log-error "AutoSysScripts\AutoSysBatch.config existed"
			    Get-ChildItem $TargetPath\$folder -force
			    Notify "Purging folder $TargetPath\$folder failed."
		        throw "Purging folder $TargetPath\$folder failed."
             }
        }
        else {
            
             Purge-TargetPath "$TargetPath\$folder" -exclude "eqfx","IncomingEquifaxFiles", "log"
     

		      # Check purging result
               if (((Get-ChildItem $TargetPath\$folder | Measure-Object).Count -eq 2) -and ((Test-Path $TargetPath\$folder\eqfx) -and (Test-Path $TargetPath\$folder\IncomingEquifaxFiles))){	
               
                    log-info "($OctopusEnvironmentName) Purging folder $TargetPath\$folder Successful."
		       }
               elseif (((Get-ChildItem $TargetPath\$folder | Measure-Object).Count -eq 3) -and (Test-Path $TargetPath\$folder\eqfx) -and (Test-Path $TargetPath\$folder\IncomingEquifaxFiles) -and (Test-Path $TargetPath\$folder\log))
              {
                log-info "($OctopusEnvironmentName) log folder existed inside $TargetPath\$folder"
                log-info "($OctopusEnvironmentName) Purging folder $TargetPath\$folder Successful"
              } 
               else {
			         log-error "($OctopusEnvironmentName) Purging folder $TargetPath\$folder failed."
			         Get-ChildItem $TargetPath\$folder -force
			         Notify "Purging folder $TargetPath\$folder failed."
			         throw "Purging folder $TargetPath\$folder failed."
               }
		}
		
		log-info "($OctopusEnvironmentName) Updating configurations." 
		$UpdateConfigScript=$OctopusOriginalPackageDirectoryPath + "\UpdateConfigurationFiles.ps1"
		. $UpdateConfigScript
		if($?){
			 log-info "($OctopusEnvironmentName) Update Config File Completed."
		}else{
			 log-error "($OctopusEnvironmentName) Unable to update config file. See logs "
			 throw "($OctopusEnvironmentName) Unable to update config file. See logs "
		}
		#Copy files to target folder
		log-info "($OctopusEnvironmentName) Copy files to $folder folder."
		Robocopy $OctopusOriginalPackageDirectoryPath $TargetPath\$folder /E /NFL /NDL /NJS /NJH /XF "$OctopusOriginalPackageDirectoryPath\AutoSysScripts\AutoSysBatch.config" PreDeploy.ps1 UpdateConfigurationFiles.ps1 common_functions.ps1
        
        
        #start of encription process
        #$Regiis_EXE = "C:\Windows\Microsoft.NET\Framework\v2.0.50727\aspnet_regiis.exe"
		$Regiis_EXE = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe"
        log-info "($OctopusEnvironmentName) Running Encryption Process for $Targetpath/$folder"
        if (Test-Path $TargetPath\$folder\escmd.exe.config) {

    
            if (Copy-Item $TargetPath\$folder\escmd.exe.config -Destination $TargetPath\$folder\web.config) {
                    log-error "Error copying escmd.exe.config for $Targetpath/$folder"
                    throw "Error copying escmd.exe.config for $Targetpath/$folder"
            }
    
            #Replace pgpConfig with pgpConfigx
            #make sure to leave quotations,work around for only the first pgpConfig changed
            (Get-Content $TargetPath\$folder\web.config) -replace ('"pgpConfig"', '"pgpConfigx"') | Set-Content $TargetPath\$folder\web.config
    
            #encript files
            & $Regiis_EXE -pef 'batchConfigGroup/sftpProfiles' $TargetPath\$folder -prov DataProtectionConfigurationProvider
            & $Regiis_EXE -pef 'connectionStrings' $TargetPath\$folder -prov DataProtectionConfigurationProvider
            & $Regiis_EXE -pef 'batchConfigGroup/pgpConfig' $TargetPath\$folder -prov DataProtectionConfigurationProvider

            #Rewrite pgpConfigx back to pgpConfig
            (Get-Content $TargetPath\$folder\web.config) -replace ('pgpConfigx', 'pgpConfig') | Set-Content $TargetPath\$folder\web.config
    
            #making a back-up of original configuration files
            Copy-Item $TargetPath\$folder\escmd.exe.config -Destination $TargetPath\$folder\escmd.exe.org.config
            Copy-Item $TargetPath\$folder\web.config -Destination $TargetPath\$folder\escmd.exe.config
   
        }
        else {
            log-error "($OctopusEnvironmentName) file $TargetPath\$folder\escmd.exe.config does not exist"
            throw "($OctopusEnvironmentName) file $TargetPath\$folder\escmd.exe.config does not exist"
        }
        
        log-info "($OctopusEnvironmentName) Finished Encypting Process for $Targetpath/$folder"
	}
    #Start-Service -Name "MSA-ESA Notifications"
	exit 0
} catch {
	log-error "($OctopusEnvironmentName) Catch: Deployment script failure! Please check Octopus log for details."
	log-error "($OctopusEnvironmentName) $($_.Exception.Message)"
	log-error "($OctopusEnvironmentName) $($_.InvocationInfo.PositionMessage)"
	$DeployLink = "<p> <BR><H3>Octopus Deployment Link</H3> <table> <tr> <td>$($OctopusSvrURL)/app#/projects/$($OctopusParameters["Octopus.Project.Name"])/releases/$($OctopusParameters["Octopus.Release.Number"])/deployments/$($OctopusParameters["Octopus.Deployment.Id"])</td> </tr> </table> </p>".Replace("_","-")
	$Body = "<style> $CSS </style>" + "<body>"
	$Body += "<H1>The deployment of the $OctopusPackageName nuget package has failed.</H1>"
	$Body += "<BR> Error(s) found: <BR>$($_.Exception.Message) <BR> $($_.InvocationInfo.PositionMessage)".Replace("`n","<BR>").Replace("`r","").Replace("<BR><BR><BR>","<BR><BR>").Replace(" ","&nbsp;")
	$Body += "$DeployLink" + " </body>"
	Notify "$Body"
	throw "$($_.Exception.Message)"
}
