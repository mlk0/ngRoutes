function Notify([string]$Body)
	{
		if ($OctoSMTPServer) {
			$RFCNum=""
			if($IncludeRFC){
			#notification variables
                # following commented-out block is replaced by non-commented-out block below 
				#$branch = $OctopusProjectName -replace $Project_Prefix,''
				#$RepoIP = "\\10.32.28.88"
				#$RFCTxt = "$RepoIP\$Project_Prefix"+"BuildRepository\$branch\$OctopusReleaseNumber"+"_RFC.txt"
				#$RFCNum = Get-Content $RFCTxt -First 1
                if($OctopusParameters["Octopus.Action[Notify Manual Intervention].Output.RFCNumber"]){
					$RFCNum = $OctopusParameters["Octopus.Action[Notify Manual Intervention].Output.RFCNumber"]
				}elseif($OctopusParameters["Octopus.Action[Notify Start].Output.RFCNumber"]){
					$RFCNum = $OctopusParameters["Octopus.Action[Notify Start].Output.RFCNumber"]
				}
			}
			log-info "($OctopusEnvironmentName) Setting up error notification message and DLs"
			$Subject = "$RFCNum $OctopusEnvironmentName" + ": $OctopusProjectName $OctopusReleaseNumber deployment Failed"
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
			log-info "($OctopusEnvironmentName) Sending error notification for $OctopusProjectName $OctopusReleaseNumber Orchard Web deployment"
			$SMTPClient.Send($mailmessage)
			log-info "($OctopusEnvironmentName) Notification sent for $OctopusProjectName $OctopusReleaseNumber Orchard Web deployment"
		} else {
			log-warn "($OctopusEnvironmentName) OctoSMTPServer variable not set. The $OctopusEnvironmentName environment may not have been setup to send email."
		}
	}

function UpdateConfigFile([string]$ConfigFile, [string]$MatchString, [string]$ReplaceString, [string]$Matchname)
{
	log-info "($OctopusEnvironmentName) Updating: $Matchname"
	log-info "($OctopusEnvironmentName) In File: $ConfigFile"
	log-info "($OctopusEnvironmentName) Search: $MatchString"
	log-info "($OctopusEnvironmentName) Replace: $ReplaceString"

	$MatchList=$MatchString -split "\|"
	$ReplaceList=$ReplaceString -split "\|"
	
	if ($MatchList.Length -ne $ReplaceList.Length) {
		log-error "$MatchName lists are not matching."
		Notify "$MatchName lists are not matching."
		throw "$MatchName lists are not matching."
	}
	
	$i=$MatchList.Length - 1
	while ($i -ge 0)
	{
		$searchPattern=$MatchList[$i]
		$ReplaceString=$ReplaceList[$i]
		SearchReplaceInFile $ConfigFile $searchPattern $ReplaceString
		$i--
	}
}

function UpdateConfigFileDB([string]$ConfigFile, [string]$MatchString, [string]$ReplaceString, [string]$Matchname)
{
	log-info "($OctopusEnvironmentName) Updating: $Matchname"
	log-info "($OctopusEnvironmentName) In File: $ConfigFile"
	log-info "($OctopusEnvironmentName) Search: $MatchString"
	log-info "($OctopusEnvironmentName) Replace: $ReplaceString"

	$MatchList=$MatchString -split "\|"
	$ReplaceList=$ReplaceString -split "\|"
	
	if ($MatchList.Length -ne $ReplaceList.Length) {
		log-error "$MatchName lists are not matching."
		Notify "$MatchName lists are not matching."
		throw "$MatchName lists are not matching."
	}
	
	$i=$MatchList.Length - 1
	while ($i -ge 0)
	{
		$searchPattern=$MatchList[$i]
		$ReplaceString=$ReplaceList[$i]
		SearchReplaceInFileDB $ConfigFile $searchPattern $ReplaceString
		$i--
	}
}

function SearchReplaceInFileDB([string]$FilePath, [string]$SearchPattern, [string]$ReplaceString)
{
	if (test-path $FilePath) {
		$Content = (Get-Content $FilePath | Foreach-Object{$_ -replace $SearchPattern, $ReplaceString})
		Set-Content $FilePath -value $Content 
	} else {
		log-warn "($OctopusEnvironmentName) $FilePath does not exist."
	}
}
function SearchReplaceInFile([string]$FilePath, [string]$SearchPattern, [string]$ReplaceString)
{
	if (test-path $FilePath) {
		$Content = (Get-Content $FilePath -Encoding UTF8| Foreach-Object{$_ -replace $SearchPattern, $ReplaceString})
		Set-Content $FilePath -value $Content -encoding UTF8
	} else {
		log-warn "($OctopusEnvironmentName) $FilePath does not exist."
	}
}

function SearchReplaceInString([string]$myString, [string]$SearchPattern, [string]$ReplaceString)
{
	$myString = $myString -replace $SearchPattern, $ReplaceString
	return $mystring
}

function ReplaceFile([string]$RemovingFile, [string]$NewFile)
{
	log-info "($OctopusEnvironmentName) Update $RemovingFile from $NewFile"
	if ((test-path $RemovingFile) -And (test-path $NewFile))
	{
		Remove-item $RemovingFile
		Rename-item $NewFile $RemovingFile
	}
}
function SetAcl ([string]$Path, [string]$Access, [string]$Permission) {

		# Get ACL on FOlder
		$GetACL = Get-Acl $Path

		# Set up AccessRule
		$Allinherit = [system.security.accesscontrol.InheritanceFlags]"ContainerInherit, ObjectInherit"
		$Allpropagation = [system.security.accesscontrol.PropagationFlags]"None"
		$AccessRule = New-Object system.security.AccessControl.FileSystemAccessRule($Access, $Permission, $AllInherit, $Allpropagation, "Allow")

		# Check if Access Already Exists
		if ($GetACL.Access | Where { $_.IdentityReference -eq $Access}) {
			log-info "($OctopusEnvironmentName) Modifying Permissions For: $Access"
			$AccessModification = New-Object system.security.AccessControl.AccessControlModification
			$AccessModification.value__ = 2
			$Modification = $False
			$GetACL.ModifyAccessRule($AccessModification, $AccessRule, [ref]$Modification) | Out-Null
		} else {
			log-info "($OctopusEnvironmentName) Adding Permission: $Permission For: $Access"
			$GetACL.AddAccessRule($AccessRule)
		}

		Set-Acl -aclobject $GetACL -Path $Path
		log-info "($OctopusEnvironmentName) Permission: $Permission Set For: $Access"
	}

function ToggleWindowsService ([string]$ServiceName, [string]$Svc_cmd) {
	$svc = get-service | where-object {$_.DisplayName -eq $ServiceName}

	if($Svc_cmd -eq "start"){
		if($svc.status -eq "Stopped"){
			log-info "($OctopusEnvironmentName) Starting stopped service $($svc.displayname)."
			start-service $svc.displayname
		} else {
			log-warn "($OctopusEnvironmentName) The service $($svc.displayname) is already in a running state."
		}
	} else {
		if($svc.status -eq "Running"){
			log-info "($OctopusEnvironmentName) Stopping running service $($svc.displayname)."
			stop-service $svc.displayname
		} else {
			log-warn "($OctopusEnvironmentName) The service $($svc.displayname) is already in a stopped state."
		}
	}
	$svc = get-service | where-object {$_.DisplayName -eq $ServiceName}
	log-info "($OctopusEnvironmentName) Windows service $($svc.displayname) status: $($svc.status)"
}
	
function CheckLogFile([string]$File, [string[]]$SearchList)
	{
		log-info "($OctopusEnvironmentName) Checking $File for known errors"
		[string]$Content = ""
		foreach($err_msg in $SearchList) {
			$Content += (Get-Content $File -Encoding UTF8| Select-String -Pattern "$err_msg" )
		}
		if ($Content) {
			log-error "($OctopusEnvironmentName) Errors found please check the log $File."
			log-error "Error found: $content"
			Notify "Errors found please check the log $File."
			throw "Error found: $content"
		}
	}
function Update-AttributeValue ([string] $FilePath,[string] $xpath, [string] $OldValue, [string] $NewValue) {

    # Get the config file contents
    $WebConfig = [XML] (Get-content $Filepath)

    #Find the url using xpath which has old Machine name 
    $hostnameString= Select-XML -XML $WebConfig -XPath $Xpath

    Foreach ( $hostname in $hostnameString) { 

		if ( ($hostname.Node.value -match $OldValue) -eq $true ) {
			log-info "Find Old Value $$hostname.Node.value"
			$hostname.Node.value = $hostname.Node.value.replace($OldValue,$NewValue)

           }
    }

 $WebConfig.Save($FilePath)
}

function Update-SiteFile ([string] $FilePath, [string] $OldValue, [string] $NewValue) {
	(Get-content $Filepath) | Foreach-Object {$_ -replace $OldValue, $NewValue} | out-file $Filepath
}

function PurgePathOrCreate ([string] $TargetPath){
	if (Test-Path $TargetPath) {
		log-info "($OctopusEnvironmentName) The directory $TargetPath exists. Purging it."
		Get-ChildItem $TargetPath -force
		log-info "($OctopusEnvironmentName) Reset Attributes"
		Get-ChildItem $TargetPath -force -recurse | foreach {$_Attributes = 'Normal'}
		log-info "($OctopusEnvironmentName) Remove everything"
		Get-ChildItem $TargetPath -force | remove-item -force -recurse
		# Check purging result
		if (!(Get-ChildItem $TargetPath -force)) {
			log-info "($OctopusEnvironmentName) Purging folder $TargetPath Successful."
		} else {
			log-error "($OctopusEnvironmentName) Purging folder $TargetPath failed."
			Get-ChildItem $TargetPath -force
			Notify "Purging folder $TargetPath failed."
			throw "Purging folder $TargetPath failed."
		}
	} else {
		log-info "($OctopusEnvironmentName) The directory $TargetPath does not exist, creating it."
		New-Item -ItemType directory -Path $TargetPath
	}
}

function PurgePathOrError([string] $TargetPath){
	if (Test-Path $TargetPath) {
		log-info "($OctopusEnvironmentName) Purge folder $TargetPath"
		Get-ChildItem $TargetPath -force
		log-info "($OctopusEnvironmentName) Reset Attributes"
		Get-ChildItem $TargetPath -force -recurse | foreach {$_Attributes = 'Normal'}
		log-info "($OctopusEnvironmentName) Remove everything"
		Get-ChildItem $TargetPath -force | remove-item -force -recurse

		# Check purging result
		if (!(Get-ChildItem $TargetPath -force)) {
			log-info "($OctopusEnvironmentName) Purging folder $TargetPath Successful."
		} else {
			log-error "($OctopusEnvironmentName) Purging folder $TargetPath failed."
			Get-ChildItem $TargetPath -force
			Notify "Purging folder $TargetPath failed."
			throw "Purging folder $TargetPath failed."
		}
	} else {
		log-error "($OctopusEnvironmentName) $TargetPath does not exist! Please verify that the service is properly setup."
		Get-ChildItem $TargetPath -force
		Notify "$TargetPath does not exist! Please verify that the service is properly setup."
		throw "$TargetPath does not exist! Please verify that the service is properly setup."
	}
}

function Get-LockingProcesses {
    [cmdletbinding()]
    Param(
        [Parameter(Position=0, Mandatory=$True,
        HelpMessage="Given a TargetPath, will return object(s) for all locked processes in/from the TargetPath (including nested folders)`
         containing the following properties: User, Path, ProgramName, PID, Type.
         Note: Can contain duplicates which should/can be removed using the get-unique cmdlet or -unique parameter. Requires elevated privileges.
         Suggested usage:Get-LockingProcesses TargetPath|Select-Object -Property User,Path,PID -Unique |Format-List -Property Path,PID -GroupBy User|Out-String")]
        [Alias("name")]
        [ValidateNotNullorEmpty()]
        [string]$TargetPath,

        [Parameter(Position=1, Mandatory=$False,
        HelpMessage="Exclude file(s)/folder(s) from investigation. Input a string or string array.")]
        [Alias("Ignore")]
        $exclude = ""
    )
    # Define the path to Handle
    $Handle = "$BuildToolsPath\Exec\handle.exe"

    [regex]$matchPattern = "(?<Name>\w+\.\w+)\s+pid:\s+(?<PID>\d+)\s+type:\s+(?<Type>\w+)\s+(?<User>\S+)\s+\w+:\s+(?<Path>.*)"

    Get-ChildItem $TargetPath -Exclude $exclude -force | foreach {#$_
        $LockedInfo = &$handle /accepteula -u $_.FullName | Out-String
		log-info "Extra Logging Info:"
		log-info "$LockedInfo"
        $LockedInfoLines = $LockedInfo -split '\r\n'
        foreach ($LockedInfoLine in $LockedInfoLines){
            $Matches = $matchPattern.Matches($LockedinfoLine)
            #$Matches
            if ($Matches.count) {
                $Matches| foreach{
                    $obj = new-object psobject -Property @{
                            User = $_.Groups["User"].value
                            Path = $_.Groups["Path"].value
                            ProgramName = $_.Groups["Name"].value
                            PID = $_.Groups["PID"].value
                            Type = $_.Groups["Type"].value
                        }
                    $obj # Output which will be returned
                }#$Match
            }#if
        }#LockedInfoLine   
    }#$_
} #end function

function Purge-TargetPath {
    [cmdletbinding()]
    Param(
        [Parameter(Position=0, Mandatory=$True,
        HelpMessage="Given a TargetPath (string of a folder),this will reset attributes of items within and purge the folder.
         Will return an error and information on if this failure is caused by locked files/processes if applicable.
         Example Usage: Purge-TargetPath(C:/deletethisfolder)")]
        [Alias("name")]
        [ValidateNotNullorEmpty()]
        [string]$TargetPath,

        
        [Parameter(Position=1, Mandatory=$False,
        HelpMessage="Exclude file(s)/folder(s) from purging. Input a string or string array.")]
        [Alias("Ignore")]
        $exclude = ""
    )

    try{
		#log-info "($OctopusEnvironmentName) The directory $TargetPath exists. Purging it." Checking if path exists is performed in predeploy.
		log-info "($OctopusEnvironmentName) Purging directory $TargetPath."
        Get-ChildItem $TargetPath -force
		log-info "($OctopusEnvironmentName) Reset Attributes"
		Get-ChildItem $TargetPath -force -recurse | foreach {$_Attributes = 'Normal'}
        log-info "($OctopusEnvironmentName) Remove everything except exclusions: $exclude"
    }
    catch{
        throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
    }
    try{
		Get-ChildItem $TargetPath -Exclude $exclude -force | remove-item -force -recurse
    }
    catch{		
        $OutString = "Purging folder $TargetPath failed. The following folders/files/processes within are locked and cannot be purged:"
	    log-error "($OctopusEnvironmentName) $OutString"
	    $OutString2 = Get-LockingProcesses $TargetPath -exclude $exclude|Select-Object -Property User,Path,PID -Unique |`
					    Format-List -Property Path,PID -GroupBy User|Out-String
        if(!$Outstring2){ #Handle could not find any locking processes. Try 2 more times.
            log-info "Handle.exe could not find any locking processes. Attempting to purge again..."
            $OutString2 += "Handle.exe could not find any locking processes. Attempting to purge again after 30s..."
            Start-Sleep -s 30
            try{Get-ChildItem $TargetPath -Exclude $exclude -force | remove-item -force -recurse}
            Catch{
                log-info "Second purge attempt failed. Attempting to purge again after 30s..."
                $OutString2 +="Second purge attempt failed. Attempting to purge again after 30s..."  
                try{Get-ChildItem $TargetPath -Exclude $exclude -force | remove-item -force -recurse}
                Catch{
                    log-info "Third purge attempt failed. Aborting Purge."
                    $OutString2 +="Third purge attempt failed. Aborting Purge."
                    $errormsg = "$OutString $OutString2 `n $($_.InvocationInfo.PositionMessage)"
                    throw $errormsg
                }
            }
        }else{ # Handle has found a locking process/user. Throw error.   
	        log-info "($OctopusEnvironmentName) $OutString2"
            $errormsg = "$OutString $OutString2 `n $($_.InvocationInfo.PositionMessage)"
            #.Replace("`n","<BR>").Replace("`r","").Replace("<BR><BR><BR>","<BR><BR>").Replace(" ","&nbsp;") Move this to Predeploy where the
            # html body is being created. This is not done here for generality.
            throw $errormsg
        }
    }
    try{
    	# Check purging result. 
		if (!(Get-ChildItem $TargetPath -force)) {
			log-info "($OctopusEnvironmentName) Purging folder $TargetPath Successful."
		}elseif(!(Get-ChildItem $TargetPath -Exclude $exclude -force)){
             foreach($excludepath in $exclude){
                if(Test-Path $TargetPath\$excludepath){
                    log-info "($OctopusEnvironmentName) $excludepath file/folder exists (excluded from purge)"
                }
            }
            log-info "($OctopusEnvironmentName) Purging folder $TargetPath Successful."
        } else {#Should not ever be reached since remove-item should throw an error causing earlier termination. In here "just in case"???
			log-error "($OctopusEnvironmentName) Purging folder $TargetPath failed."
			Get-ChildItem $TargetPath -force
			Notify "Purging folder $TargetPath failed."
			throw "($OctopusEnvironmentName) Purging folder $TargetPath failed."
		}
    }
    catch{
        throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
    }
} #end function