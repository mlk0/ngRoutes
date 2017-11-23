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

	log-info "($OctopusEnvironmentName) DB deployment for $OctopusProjectName $OctopusReleaseNumber"
	log-info "($OctopusEnvironmentName) Parameters passed in:"
	log-info "($OctopusEnvironmentName) TargetPath: $TargetPath"
	log-info "($OctopusEnvironmentName) OctopusOriginalPackageDirectoryPath: $OctopusOriginalPackageDirectoryPath"
	log-info "($OctopusEnvironmentName) BuildToolsPath $BuildToolsPath"
	#--------------------------------------------------
	# Environment variables
	[string]$date= (Get-Date).ToString("yyyy-MM-dd")
	[string]$dblog = "$OctopusEnvironmentName" + "_content_$date.log"
	[string[]]$db_error_list = "\[ERROR\]"

	if (Test-Path "$BuildToolsPath\Email\securestring.txt") {
		$pw = Get-Content "$BuildToolsPath\Email\securestring.txt" #| convertto-securestring -key $securekey
	} else {
		log-warn "($OctopusEnvironmentName) $BuildToolsPath\Email\securestring.txt does not exist"
	}
	
} catch {
	write-output "Problem has occurred with the script that may be related to log4net or email setup. Please review Octopus Deploy log."
	throw "Problem has occurred with the script that may be related to log4net or email setup. Please review Octopus Deploy log."
}

try {
	#--------------------------------------------------
	# Run DB scripts
	$error.clear()
	$ErrorActionPreference = "Stop"

	# Purging target folder
	if (Test-Path $TargetPath) {
        log-info "($OctopusEnvironmentName) The directory $TargetPath exists. Purging it."
        Purge-TargetPath $TargetPath
	} else {
		log-info "($OctopusEnvironmentName) The directory $TargetPath does not exist, creating it."
		New-Item -ItemType directory -Path $TargetPath
	}

	log-info "($OctopusEnvironmentName) Updating config files"
	if (Test-Path $OctopusOriginalPackageDirectoryPath\UpdateConfigurationFiles.ps1) {
		& "$OctopusOriginalPackageDirectoryPath\UpdateConfigurationFiles.ps1"
	} else {
		throw "Unable to find $OctopusOriginalPackageDirectoryPath\UpdateConfigurationFiles.ps1"
	}

	log-info "($OctopusEnvironmentName) Copy files from OctopusOriginalPackageDirectoryPath : $OctopusOriginalPackageDirectoryPath to TargetPath : $TargetPath"
	Robocopy $OctopusOriginalPackageDirectoryPath $TargetPath /S /MIR /NFL /NDL /NJS /NJH /XF PreDeploy.ps1 UpdateConfigurationFiles.ps1 common_functions.ps1

	# Run EncryptConfigFile.ps1 script if it exists
	if (Test-Path $OctopusOriginalPackageDirectoryPath\EncryptConfigFile.ps1) {
	  & "$OctopusOriginalPackageDirectoryPath\EncryptConfigFile.ps1"
	}

	log-info "($OctopusEnvironmentName) Application deployment completed."
	$DeployLink = "<p> <BR><H3>Octopus Deployment Link</H3> <table> <tr> <td>$($OctopusSvrURL)/app#/projects/$($OctopusParameters["Octopus.Project.Name"])/releases/$($OctopusParameters["Octopus.Release.Number"])/deployments/$($OctopusParameters["Octopus.Deployment.Id"])</td> </tr> </table> </p>".Replace("_","-")
	$Body = "<style> $CSS </style>" + "<body>"
	$Body += "<H1>The deployment of the $OctopusPackageName nuget package has succeeded.</H1>"
	$Body += "$DeployLink" + " </body>"
	if ($OctoSMTPServer) {
		log-info "($OctopusEnvironmentName) Setting up error notification message and DLs"
		$Subject = "$RFCNum $OctopusEnvironmentName" + ": $OctopusProjectName $OctopusReleaseNumber DB package deployment Completed"
		$SMTPClient = New-Object Net.Mail.SmtpClient($OctoSMTPServer, 25)
		$SMTPClient.Credentials = New-Object System.Net.NetworkCredential("$usr","$pw");
		$mailmessage = New-Object system.net.mail.mailmessage 
		$mailmessage.from = ($EmailFrom)
		$ErrorDLTo = $ErrorDLTo -split ","
		$ErrorDLTo | foreach {$mailmessage.To.Add((New-Object System.Net.Mail.Mailaddress $_.Trim()))}
		# Add email addresses in CC DL if it exists
		if ($ErrorDLCC) {
			$ErrorDLCC = $ErrorDLCC -split ","
			$ErrorDLCC | foreach {$mailmessage.CC.Add((New-Object System.Net.Mail.Mailaddress $_.Trim()))}
		}
		$mailmessage.Subject = $Subject
		$mailmessage.IsBodyHTML = $true 
		$mailmessage.Body = $Body
		if (Test-Path "$TargetPath") {
			$logfiles = Get-ChildItem -Path $TargetPath | where {$_.extension -eq ".log"} | select fullname
		}
		if ($logfiles) {
			$logfiles | foreach {$mailmessage.Attachments.Add((New-Object System.Net.Mail.Attachment($($_.fullname), 'text/plain')))}
		} else {
			log-info "($OctopusEnvironmentName) No log files found."
		}
		log-info "($OctopusEnvironmentName) Sending success notification for $OctopusProjectName $OctopusReleaseNumber Orchard Web deployment"
		$SMTPClient.Send($mailmessage)
		log-info "($OctopusEnvironmentName) Notification sent for $OctopusProjectName $OctopusReleaseNumber Orchard Web deployment"
	} else {
		log-warn "($OctopusEnvironmentName) OctoSMTPServer variable not set. The $OctopusEnvironmentName environment may not have been setup to send email."
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

