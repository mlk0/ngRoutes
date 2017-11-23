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
try {
	# Load log4net
	push-location "$BuildToolsPath\Logging"
	. .\LoggingFunctions.ps1
	pop-location

	log-info "($OctopusEnvironmentName) Windows Services deployment for $OctopusProjectName $OctopusReleaseNumber"
	log-info "($OctopusEnvironmentName) Parameters passed in:"
	log-info "($OctopusEnvironmentName) OctopusPackageDirectoryPath $TargetPath"
	log-info "($OctopusEnvironmentName) OctopusOriginalPackageDirectoryPath $OctopusOriginalPackageDirectoryPath"
	log-info "($OctopusEnvironmentName) BuildToolsPath $BuildToolsPath"

} catch {
	write-output "Problem has occurred with the script that may be related to log4net or email setup. Please review Octopus Deploy log."
	throw "Problem has occurred with the script that may be related to log4net or email setup. Please review Octopus Deploy log."
}

try {
	
	# Stop  windows services
	if (Get-service | where-object {$_.DisplayName -eq $servicename})  {
		log-info "($OctopusEnvironmentName) Stopping the window service for $servicename."
		ToggleWindowsService $servicename stop
		# Wait 60 seconds for lingering processes to complete and release
		log-info "($OctopusEnvironmentName) Waiting $wait_time seconds for processes to release locked files."
		Start-Sleep -s $wait_time
	} else {
		# Creates Windows service if it does not exist
		log-info "($OctopusEnvironmentName) $servicename does not exist. Creating Windows service for $servicename.."
		$exe = Get-ChildItem -path "$OctopusOriginalPackageDirectoryPath" -Recurse | where {$_.extension -eq ".exe"} | Select Name
		$fullpath = "$TargetPath" + "\" + "$($exe.Name)"
		#Runs on default LocalSystem account if there are no credentials			
		if (!$svcusername -and !$svcpassword) {      
			log-warn "No credentials parameter are given for the new windows service, the $servicename service will use LocalSystem account"
			New-Service -Name $servicename -BinaryPathName "$fullpath" -displayName $servicename -StartupType Automatic
		} else {                                           
			#Creates new service using the given credentials		
			$pass = $svcpassword | ConvertTo-SecureString -AsPlainText -Force
			$cred = New-Object System.Management.Automation.PSCredential ("$svcusername", $pass) #Gets the service account credentials for the windows service
			New-Service -Name $servicename -BinaryPathName "$fullpath" -displayName $servicename -Credential $cred -StartupType Automatic
		}
			log-info "($OctopusEnvironmentName) Successfully created windows services for $servicename"
	}
	if (Test-Path $TargetPath) {
		# Purging target path
        log-info "($OctopusEnvironmentName) The directory $TargetPath exists. Purging it."
        Purge-TargetPath $TargetPath
	} else {
		#If purge fails creates a new directory with full path
		log-warn "($OctopusEnvironmentName) $TargetPath does not exist. Creating a new directory for $TargetPath"
		New-Item -ItemType directory -Path $TargetPath
		log-info "($OctopusEnvironmentName) Successfully created $TargetPath."
	}
	
	log-info "($OctopusEnvironmentName) Updating configurations."
	$UpdateConfigScript=$OctopusOriginalPackageDirectoryPath + "\UpdateConfigurationFiles.ps1"
	. $UpdateConfigScript

	if($?){
		log-info "($OctopusEnvironmentName) Update Config File Completed."
	} else {
		log-error "($OctopusEnvironmentName) Unable to update config file. See logs "
		throw "($OctopusEnvironmentName) Unable to update config file. See logs "
	}

	# Copy
	log-info "($OctopusEnvironmentName) Copy files."
	Robocopy $OctopusOriginalPackageDirectoryPath $TargetPath /S /MIR /NFL /NDL /NJS /NJH /XF PreDeploy.ps1 UpdateConfigurationFiles.ps1 common_functions.ps1

	# Start all controller windows services
	if ($startWindowsServices -eq 1) {
		log-info "($OctopusEnvironmentName) Restarting the Windows services."
		log-info "($OctopusEnvironmentName) Starting up the Windows service for $servicename."
		ToggleWindowsService $servicename start
	} else {
		log-info "($OctopusEnvironmentName) environment is setup to not start Windows services."
	}
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