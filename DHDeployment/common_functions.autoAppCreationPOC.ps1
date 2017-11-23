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
		exit 1
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

function SearchReplaceInFile([string]$FilePath, [string]$SearchPattern, [string]$ReplaceString)
{
	if (test-path $FilePath) {
        if ("$ReplaceString") {
            ./fart.exe -i -r -c $FilePath "$SearchPattern" "$ReplaceString" 2>&1 | out-null
        }
        else {
            ./fart.exe -i -r -C $FilePath --remove "$SearchPattern" 2>&1 | out-null
        }
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
		log-error "Error found: $Content"
		Notify "Errors found please check the log $File."
		throw "Errors found please check the log $File."
	}
}
function Update-AttributeValue ([string] $FilePath,[string] $xpath, [string] $OldValue, [string] $NewValue) {

    # Get the config file contents
    $WebConfig = [XML] (Get-content $Filepath)

    #Find the url using xpath which has old Machine name 
    $hostnameString= Select-XML -XML $WebConfig -XPath $Xpath

    Foreach ( $hostname in $hostnameString) { 

		if ( ($hostname.Node.value -match $OldValue) -eq $true ) {
			Write-Host Find Old Value $$hostname.Node.value
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



# This has to be done in a calling function to be compatible with PS
# Add-Type -Path 'C:\Windows\system32\inetsrv\Microsoft.Web.Administration.dll' # load Micrsoft.Web.Administration assembly

function global:Get-WebSchema()
{# From: https://blogs.iis.net/jeonghwan/iis-powershell-getting-config-section-names-and-attributes-names-dynamically
        param(
            [string]$fileName=$null,
            [string]$sectionName=$null,
            [object]$nodeObject=$null,
            [switch]$list,
            [switch]$verbose
        )

        if ($list -and $sectionName -and -not $fileName)
        {
            throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
        }

        if ($list -and $recurse)
        {
            throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
        }

        if ($sectionName -and -not $fileName)
        {
            throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
        }

        if ($list)
        {
            if ($sectionName)
            {
                [xml]$xml = Get-Content $filename
                $rootNode = $xml.get_documentElement()
                $rootNode.sectionSchema | ForEach-Object {
                    $nodeObject = $_                
                    if ($nodeObject.name.tolower() -eq $sectionName.tolower())
                    {                  
                        $nodeObject
                    }
                }             
            }
            else
            {
                if ($fileName)
                {
                    [xml]$xml = Get-Content $filename
                    $rootNode = $xml.get_documentElement()
                    $rootNode.sectionSchema | ForEach-Object {
                        $sectionName = $_.name
                        $sectionName
                    }           
                }
                else
                {
                    Get-ChildItem "$env:windir\system32\inetsrv\config\schema" -filter *.xml | ForEach-Object {
                        $filePath = $_.fullname
                        $filePath
                    }
                }
            }    
        }
        else
        {
            if (-not $fileName -and -not $nodeObject) {
                throw $($(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'fileName')
            }

            if (-not $nodeObject)
            {
                [xml]$xml = Get-Content $filename
                $rootNode = $xml.get_documentElement()
                $rootNode.sectionSchema | ForEach-Object {
                    $nodeObject = $_
                    if ((-not $sectionName) -or ($nodeObject.name.tolower() -eq $sectionName.tolower()))
                    {
                        Get-WebSchema -nodeObject $_ -filename $fileName -sectionName $nodeObject.name -verbose:$verbose
                    }
                }            
            }       
            else
            {
                ("element", "collection", "attribute", "method") | ForEach-Object {
                    $type = $_.tostring()
                    if ($nodeObject.$type -ne $null) 
                    {   
                        $nodeObject.$type | ForEach-Object {
                             $leafObject = $_
                             $output = new-object psobject
                             if ($type -eq "collection") 
                             {
                                 $name = $leafObject.addElement
                                 if ($verbose)
                                 {
                                     $name = "[name]"
                                 }
                             }
                             else
                             {
                                 $name = $leafObject.name
                             }                       

                             $ItemXPath = $null
                             if ($verbose)
                             {
                                 $ItemXPath = ($sectionName+"//"+$name)
                             }
                             else
                             {
                                 $ItemXPath = ($sectionName+"/"+$name)
                             }
                             add-member -in $output noteproperty ItemXPath $ItemXPath
                             add-member -in $output noteproperty Name $name
                             add-member -in $output noteproperty XmlObject $leafObject
                             add-member -in $output noteproperty Type $leafObject.toString()
                             add-member -in $output noteproperty ParentXPath $sectionName
                             $output

                             if ($type -eq "element" -or $type -eq "collection") 
                             {
                                 Get-WebSchema -nodeObject $_ -filename $fileName -sectionName $ItemXPath -verbose:$verbose
                             }
                        }
                    }
                }
            }
        }
    }
function Use-CallerPreference
{
        <#
        .SYNOPSIS
        Sets the PowerShell preference variables in a module's function based on the callers preferences.

        .DESCRIPTION
        Script module functions do not automatically inherit their caller's variables, including preferences set by common parameters. This means if you call a script with switches like `-Verbose` or `-WhatIf`, those that parameter don't get passed into any function that belongs to a module. 

        When used in a module function, `Use-CallerPreference` will grab the value of these common parameters used by the function's caller:

         * ErrorAction
         * Debug
         * Confirm
         * InformationAction
         * Verbose
         * WarningAction
         * WhatIf
    
        This function should be used in a module's function to grab the caller's preference variables so the caller doesn't have to explicitly pass common parameters to the module function.

        This function is adapted from the [`Get-CallerPreference` function written by David Wyatt](https://gallery.technet.microsoft.com/scriptcenter/Inherit-Preference-82343b9d).

        There is currently a [bug in PowerShell](https://connect.microsoft.com/PowerShell/Feedback/Details/763621) that causes an error when `ErrorAction` is implicitly set to `Ignore`. If you use this function, you'll need to add explicit `-ErrorAction $ErrorActionPreference` to every function/cmdlet call in your function. Please vote up this issue so it can get fixed.

        .LINK
        about_Preference_Variables

        .LINK
        about_CommonParameters

        .LINK
        https://gallery.technet.microsoft.com/scriptcenter/Inherit-Preference-82343b9d

        .LINK
        http://powershell.org/wp/2014/01/13/getting-your-script-module-functions-to-inherit-preference-variables-from-the-caller/

        .EXAMPLE
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        Demonstrates how to set the caller's common parameter preference variables in a module function.
        #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            #[Management.Automation.PSScriptCmdlet]
            # The module function's `$PSCmdlet` object. Requires the function be decorated with the `[CmdletBinding()]` attribute.
            $Cmdlet,

            [Parameter(Mandatory = $true)]
            [Management.Automation.SessionState]
            # The module function's `$ExecutionContext.SessionState` object.  Requires the function be decorated with the `[CmdletBinding()]` attribute. 
            #
            # Used to set variables in its callers' scope, even if that caller is in a different script module.
            $SessionState
        )

        Set-StrictMode -Version 'Latest'

        # List of preference variables taken from the about_Preference_Variables and their common parameter name (taken from about_CommonParameters).
        $commonPreferences = @{
                                  'ErrorActionPreference' = 'ErrorAction';
                                  'DebugPreference' = 'Debug';
                                  'ConfirmPreference' = 'Confirm';
                                  'InformationPreference' = 'InformationAction';
                                  'VerbosePreference' = 'Verbose';
                                  'WarningPreference' = 'WarningAction';
                                  'WhatIfPreference' = 'WhatIf';
                              }

        foreach( $prefName in $commonPreferences.Keys )
        {
            $parameterName = $commonPreferences[$prefName]

            # Don't do anything if the parameter was passed in.
            if( $Cmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName) )
            {
                continue
            }

            $variable = $Cmdlet.SessionState.PSVariable.Get($prefName)
            # Don't do anything if caller didn't use a common parameter.
            if( -not $variable )
            {
                continue
            }

            if( $SessionState -eq $ExecutionContext.SessionState )
            {
                Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
            }
            else
            {
                $SessionState.PSVariable.Set($variable.Name, $variable.Value)
            }
        }

    }
filter Add-IisServerManagerMember
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        # The object on which the server manager members will be added.
        $InputObject,
        
        [Parameter(Mandatory=$true)]
        [Microsoft.Web.Administration.ServerManager]
        # The server manager object to use as the basis for the new members.
        $ServerManager,
        
        [Switch]
        # If set, will return the input object.
        $PassThru
    )
    
    Set-StrictMode -Version 'Latest'

    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

    $InputObject | 
        Add-Member -MemberType NoteProperty -Name 'ServerManager' -Value $ServerManager -PassThru |
        Add-Member -MemberType ScriptMethod -Name 'CommitChanges' -Value { $this.ServerManager.CommitChanges() }
        
    if( $PassThru )
    {
        return $InputObject
    }
    }
function Get-IisAppPool{
<#
.SYNOPSIS
Gets a `Microsoft.Web.Administration.ApplicationPool` object for an application pool.
    
.DESCRIPTION
The `Get-IisAppPool` function returns an IIS application pools as a `Microsoft.Web.Administration.ApplicationPool` object. Use the `Name` parameter to return the application pool. If that application pool isn't found, `$null` is returned.

Carbon adds a `CommitChanges` method on each object returned that you can use to save configuration changes.

Beginning in Carbon 2.0, `Get-IisAppPool` will return all application pools installed on the current computer.
    
Beginning with Carbon 2.0.1, this function is available only if IIS is installed.

.LINK
http://msdn.microsoft.com/en-us/library/microsoft.web.administration.applicationpool(v=vs.90).aspx
    
.OUTPUTS
Microsoft.Web.Administration.ApplicationPool.

.EXAMPLE
Get-IisAppPool

Demonstrates how to get *all* application pools.
    
.EXAMPLE
Get-IisAppPool -Name 'Batcave'
    
Gets the `Batcave` application pool.
    
.EXAMPLE
Get-IisAppPool -Name 'Missing!'
    
Returns `null` since, for purposes of this example, there is no `Missing~` application pool.
#>
[CmdletBinding()]
[OutputType([Microsoft.Web.Administration.ApplicationPool])]
param(
    [string]
    # The name of the application pool to return. If not supplied, all application pools are returned.
    $Name
)
    
Set-StrictMode -Version 'Latest'

Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

$mgr = New-Object Microsoft.Web.Administration.ServerManager
$mgr.ApplicationPools |
    Where-Object { 
        if( -not $PSBoundParameters.ContainsKey('Name') )
        {
            return $true
        }
        return $_.Name -eq $Name 
    } |
    Add-IisServerManagerMember -ServerManager $mgr -PassThru
}

function Test-IisAppPool{
    <# 
    .SYNOPSIS
    Checks if an app pool exists.

    .DESCRIPTION 
    Returns `True` if an app pool with `Name` exists.  `False` if it doesn't exist.

    Beginning with Carbon 2.0.1, this function is available only if IIS is installed.

    .EXAMPLE
    Test-IisAppPool -Name Peanuts

    Returns `True` if the Peanuts app pool exists, `False` if it doesn't.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The name of the app pool.
        $Name
    )
    
    Set-StrictMode -Version 'Latest'

    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

    $appPool = Get-IisAppPool -Name $Name
    if( $appPool )
    {
        return $true
    }
    
    return $false
    }
Set-Alias -Name 'Test-IisAppPoolExists' -Value 'Test-IisAppPool'
function Test-IisWebsite{
    <#
    .SYNOPSIS
    Tests if a website exists.

    .DESCRIPTION
    Returns `True` if a website with name `Name` exists.  `False` if it doesn't.

    Beginning with Carbon 2.0.1, this function is available only if IIS is installed.

    .EXAMPLE
    Test-IisWebsite -Name 'Peanuts'

    Returns `True` if the `Peanuts` website exists.  `False` if it doesn't.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The name of the website whose existence to check.
        $Name
    )
    
    Set-StrictMode -Version 'Latest'

    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

    $manager = New-Object 'Microsoft.Web.Administration.ServerManager'
    try
    {
        $site = $manager.Sites | Where-Object { $_.Name -eq $Name }
        if( $site )
        {
            return $true
        }
        return $false
    }
    finally
    {
        $manager.Dispose()
    }
    }

Set-Alias -Name Test-IisWebsiteExists -Value Test-IisWebsite

function Get-IisWebsite{
    <#
    .SYNOPSIS
    Returns all the websites installed on the local computer, or a specific website.
    
    .DESCRIPTION
    Returns a Microsoft.Web.Administration.Site object.

    Each object will have a `CommitChanges` script method added which will allow you to commit/persist any changes to the website's configuration.
     
    Beginning with Carbon 2.0.1, this function is available only if IIS is installed.

    .OUTPUTS
    Microsoft.Web.Administration.Site.
    
    .LINK
    http://msdn.microsoft.com/en-us/library/microsoft.web.administration.site.aspx

    .EXAMPLE
    Get-IisWebsite

    Returns all installed websites.
     
    .EXAMPLE
    Get-IisWebsite -SiteName 'WebsiteName'
     
    Returns the details for the site named `WebsiteName`.
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Web.Administration.Site])]
    param(
        [string]
        [Alias('SiteName')]
        # The name of the site to get.
        $Name
    )
    
    Set-StrictMode -Version 'Latest'

    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

    if( $Name -and -not (Test-IisWebsite -Name $Name) )
    {
        return $null
    }
    
    $mgr = New-Object 'Microsoft.Web.Administration.ServerManager'
    $mgr.Sites | 
        Where-Object {
            if( $Name )
            {
                $_.Name -eq $Name
            }
            else
            {
                $true
            }
        } | Add-IisServerManagerMember -ServerManager $mgr -PassThru
    }

function Get-IisApplication{
    <#
    .SYNOPSIS
    Gets an IIS application as an `Application` object.

    .DESCRIPTION
    Uses the `Microsoft.Web.Administration` API to get an IIS application object.  If the application doesn't exist, `$null` is returned.

    The objects returned have two dynamic properties and one dynamic methods added.

     * `ServerManager { get; }` - The `ServerManager` object which created the `Application` object.
     * `CommitChanges()` - Persists any configuration changes made to the object back into IIS's configuration files.
     * `PhysicalPath { get; }` - The physical path to the application.

    Beginning with Carbon 2.0.1, this function is available only if IIS is installed.

    .OUTPUTS
    Microsoft.Web.Administration.Application.

    .EXAMPLE
    Get-IisApplication -SiteName 'DeathStar`

    Gets all the applications running under the `DeathStar` website.

    .EXAMPLE
    Get-IisApplication -SiteName 'DeathStar' -VirtualPath '/'

    Demonstrates how to get the main application for a website: use `/` as the application name.

    .EXAMPLE
    Get-IisApplication -SiteName 'DeathStar' -VirtualPath '/MainPort/ExhaustPort'

    Demonstrates how to get a nested application, i.e. gets the application at `/MainPort/ExhaustPort` under the `DeathStar` website.
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Web.Administration.Application])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The site where the application is running.
        $SiteName,
        
        [Parameter()]
        [Alias('Name')]
        [string]
        # The name of the application.  Default is to return all applications running under the website `$SiteName`.
        $VirtualPath
    )

    Set-StrictMode -Version 'Latest'

    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

    $site = Get-IisWebsite -SiteName $SiteName
    if( -not $site )
    {
        return
    }

    $site.Applications |
        Where-Object {
            if( $VirtualPath )
            {
                return ($_.Path -eq "$VirtualPath")
            }
            return $true
        } | 
        Add-IisServerManagerMember -ServerManager $site.ServerManager -PassThru
    }

function ES_Setup-Applications{
param(
    [Parameter(Mandatory=$true)]
    [string]
    # Path to application specifications
    $webAppSettingsXMLPath,
    [Parameter(Mandatory=$false)]
    [string]
    # Location of IIS_schema.xml
    $IIS_schemaXMLPath = "C:\Windows\System32\inetsrv\config\schema\IIS_schema.xml",
    [Parameter(Mandatory=$false)]
    [string]
    # Location of applicationHost.config
    $applicationHostConfigPath = "C:\Windows\System32\inetsrv\config\applicationHost.config"
)


$DefaultApplicationDefaultsSettings = @{}
$DefaultApplicationDefaults_virtualDirectorySettings = @{}
$DefaultAuthentication_anonymousAuthenticationSettings = @{}
#$DefaultAuthentication_AspNetImpersonationSettings = @{} # Not currently done for ES
#Regarding ASP.NET Impersonation:  This setting's defaults are not stored in IIS_schema.xml This setting is not stored in Applicationhost.config. 
#This setting is saved on an application to application basis in Web.config (ex.<identity impersonate="true" />). 
#This setting has default values in ASPNET_schema.xml under system.web/identity.
$DefaultAuthentication_basicAuthenticationSettings = @{}
#$DefaultAuthentication_FormsAuthenticationSettings = @{} # Not currently done for ES
#$DefaultAuthentication_FormsAuthentication_credentialsSettings = @{} Not currently done for ES
#$DefaultAuthentication_FormsAuthentication_credentials_userSettings = @{} # Not currently done for ES
#Regarding Forms Authentication: This is something from ASP.Net. This setting's defaults are not stored in IIS_schema.xml 
#This setting is not stored in Applicationhost.config. 
#This setting is saved on an application to application basis in Web.config (ex.<authentication mode="Forms" />).
#This setting has default values in ASPNET_schema.xml under system.web/identity.
$DefaultAuthentication_windowsAuthenticationSettings = @{}
#[System.Collections.ArrayList]$DefaultAuthentication_windowsAuthentication_providersSettings = @() #Not done for ES
$DefaultAuthentication_windowsAuthentication_extendedProtectionSettings = @{} 
#[System.Collections.ArrayList]$DefaultAuthentication_windowsAuthentication_extendedProtection_spnSettings = @()#Not done for ES



# Obtaining default Application settings from IIS_schema.xml
try{
        $sitesInfo = Get-WebSchema -list -fileName $IIS_schemaXMLPath -sectionName system.applicationHost/sites


        $applicationDefaultsInfo = $sitesInfo.collection.collection.attribute
        foreach($attribute in $applicationDefaultsInfo){
            "Name: $($attribute.name)"
            if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
                "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
                $DefaultApplicationDefaultsSettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
            }
            else{"Default VALUE DNE"}
            $attribute.type
        }

        $applicationDefaults_virtualDirectoryInfo = $sitesInfo.collection.collection.collection.attribute
        foreach($attribute in $applicationDefaults_virtualDirectoryInfo){
            "Name: $($attribute.name)"
            if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
                "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
                $DefaultApplicationDefaults_virtualDirectorySettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
            }
            else{"Default VALUE DNE"}
            $attribute.type
        }

        $anonymousAuthenticationInfo = Get-WebSchema -list -fileName $IIS_schemaXMLPath -sectionName system.webServer/security/authentication/anonymousAuthentication
        foreach($attribute in $($anonymousAuthenticationInfo.attribute)){
            "Name: $($attribute.name)"
            if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
                "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
                $DefaultAuthentication_anonymousAuthenticationSettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
            }
            else{"Default VALUE DNE"}
            $attribute.type
        }

        $basicAuthenticationInfo = Get-WebSchema -list -fileName $IIS_schemaXMLPath -sectionName system.webServer/security/authentication/basicAuthentication
        foreach($attribute in $($basicAuthenticationInfo.attribute)){
            "Name: $($attribute.name)"
            if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
                "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
                $DefaultAuthentication_basicAuthenticationSettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
            }
            else{"Default VALUE DNE"}
            $attribute.type
        }

        $windowsAuthenticationInfo = Get-WebSchema -list -fileName $IIS_schemaXMLPath -sectionName system.webServer/security/authentication/windowsAuthentication
        foreach($attribute in $($windowsAuthenticationInfo.attribute)){
            "Name: $($attribute.name)"
            if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
                "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
                $DefaultAuthentication_windowsAuthenticationSettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
            }
            else{"Default VALUE DNE"}
            $attribute.type
        }
    
        foreach($attribute in $($windowsAuthenticationInfo.element | Where-Object{ $_.Name -eq "extendedProtection"}).attribute){
            "Name: $($attribute.name)"
            if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
                "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
                $DefaultAuthentication_windowsAuthentication_extendedProtectionSettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
            }
            else{"Default VALUE DNE"}
            $attribute.type
        }

    }
Catch{"Failed while obtaining info from IIS_schema.xml"
        throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
    }
# Obtaining default Application settings from applicationHost.config:
try{
        [xml]$appHostConfigXML = Get-Content -Path $applicationHostConfigPath

        #Setting Values for default ApplicationDefaults settings.
        foreach($Setting in $($appHostConfigXML.configuration.'system.applicationHost'.sites.applicationDefaults.Attributes)){
            $Setting.Name
            $Setting.Value
            $DefaultApplicationDefaultsSettings.Set_Item($Setting.Name, $Setting.Value)
        }

        #Setting Values for default virtualDirectory settings. Note that this is set for all sites and inherited by an application
        foreach($Setting in $($appHostConfigXML.configuration.'system.applicationHost'.sites.virtualDirectoryDefaults.Attributes)){
            $Setting.Name
            $Setting.Value
            $DefaultApplicationDefaults_virtualDirectorySettings.Set_Item($Setting.Name, $Setting.Value)
        }

        #AFAIK there are no other default settings for applications in applicationHost.config

    }
Catch{"Failed while obtaining info from IIS_schema.xml"
    throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
}


#Setting authentication settings for Application


"Obtaining Values from webAppSettings.xml"
[xml]$appConfigXML = Get-Content -Path $webAppSettingsXMLPath


#Foreach Application:
foreach($siteGroup in $($appConfigXML.WebAppSettings.applications.site)){
    #Getting IIS site with manager...
    $site = Get-IisWebsite -SiteName $SiteGroup.name
    if( -not $site )
    {
        Write-Error ('[IIS] Website ''{0}'' not found.' -f $SiteName)
        return
    }
    foreach($appconfig in $($siteGroup.application)){
        # Copy Dictionaries
        $ApplicationDefaultsSettings = $DefaultApplicationDefaultsSettings.PsObject.Copy()
        #$ApplicationDefaults_virtualDirectorySettings = $DefaultApplicationDefaults_virtualDirectorySettings.PsObject.Copy()# This is done later as an application can have multiple virtual directories.
        $Authentication_anonymousAuthenticationSettings = $DefaultAuthentication_anonymousAuthenticationSettings.PsObject.Copy()
        $Authentication_basicAuthenticationSettings = $DefaultAuthentication_basicAuthenticationSettings.PsObject.Copy()
        $Authentication_windowsAuthenticationSettings = $DefaultAuthentication_windowsAuthenticationSettings.PsObject.Copy()
        $Authentication_windowsAuthentication_extendedProtectionSettings = $DefaultAuthentication_windowsAuthentication_extendedProtectionSettings.PsObject.Copy()

        # modify dictionary with overwrite values for Applications
        "Overwriting default settings with settings from applications.xml"
        try{

            #Setting Values for default Element which is assumed to be ApplicationDefaults
            foreach($Setting in $($appConfig.Attributes)){
                if($Setting){
					$Setting.Name
					$Setting.Value
					$ApplicationDefaultsSettings.Set_Item($Setting.Name, $Setting.Value)
				}
            }

            #Setting Values for ApplicationDefaults. This is for the event that this info is stored with explicit structure.
            foreach($Setting in $($appConfig.ApplicationDefaults.Attributes)){
                if($Setting){
					$Setting.Name
					$Setting.Value
					$ApplicationDefaultsSettings.Set_Item($Setting.Name, $Setting.Value)
				}
            }

            #Setting Values for Virtual Directory
            <# This is done later as an application can have multiple virtual directories.
            foreach($Setting in $($appConfig.virtualDirectory.Attributes)){
                $Setting.Name
                $Setting.Value
                $ApplicationDefaults_virtualDirectorySettings.Set_Item($Setting.Name, $Setting.Value)
            }#>

            #Setting Values for anonymous authentication
            foreach($Setting in $($appConfig.security.authentication.anonymousAuthentication.Attributes)){
                if($Setting){
					$Setting.Name
					$Setting.Value
					$Authentication_anonymousAuthenticationSettings.Set_Item($Setting.Name, $Setting.Value)
				}
            }
            #Setting Values for basic authentication
            foreach($Setting in $($appConfig.security.authentication.basicAuthentication.Attributes)){
                if($Setting){
					$Setting.Name
					$Setting.Value
					$Authentication_basicAuthenticationSettings.Set_Item($Setting.Name, $Setting.Value)
				}
            }
            #Setting Values for windows authentication
            foreach($Setting in $($appConfig.security.authentication.windowsAuthentication.Attributes)){
                if($Setting){
					$Setting.Name
					$Setting.Value
					$Authentication_windowsAuthenticationSettings.Set_Item($Setting.Name, $Setting.Value)
				}
            }
            
            foreach($Setting in $($appConfig.security.authentication.windowsAuthentication.extendedProtection.Attributes)){
                if($Setting){
					$Setting.Name
					$Setting.Value
					$Authentication_windowsAuthentication_extendedProtectionSettings.Set_Item($Setting.Name, $Setting.Value)
				}
            }
        }
        Catch{"Failed while overwriting default settings with settings from applications.xml"    
                throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"}
    }

    #Set all values of an Applications to its dictionary's values. Create Application if needed.
    "Setting Values"
    try{
        $app = Get-IisApplication -SiteName $SiteGroup.name -VirtualPath $ApplicationDefaultsSettings["path"]
        if( -not $app )
        {
            Write-Verbose ('IIS://{0}: creating application' -f $iisAppPath)
            $apps = $site.GetCollection()
            $app = $apps.CreateElement('application') |
                        Add-IisServerManagerMember -ServerManager $site.ServerManager -PassThru
            $app['path'] = $ApplicationDefaultsSettings["path"]
            $apps.Add( $app ) | Out-Null
        }

        foreach($kvp in $ApplicationDefaultsSettings.GetEnumerator()){ # Key-value pair
            try{$app.$($kvp.key) = $kvp.value}
            Catch{$app.SetAttributeValue($($kvp.key), $($kvp.value))} # Catch statement is needed as some attributes are stored in "Raw attributes"
            #Cannot use just use what is in the catch statement because what is in the Catch statement is a C# function which requires explicit typing
        }
		
        foreach($virtualDirectory in $($appConfig.virtualDirectory)){
            $ApplicationDefaults_virtualDirectorySettings = $DefaultApplicationDefaults_virtualDirectorySettings.PsObject.Copy()
			#Setting Values for Virtual Directory
            foreach($Setting in $virtualDirectory.Attributes){
                if($Setting){
					$Setting.Name
					$Setting.Value
					$ApplicationDefaults_virtualDirectorySettings.Set_Item($Setting.Name, $Setting.Value)
				}
            }
			if(! $(Test-Path -Path $ApplicationDefaults_virtualDirectorySettings["physicalPath"])){New-Item -Path $ApplicationDefaults_virtualDirectorySettings["physicalPath"] -ItemType directory}
            $vdir = $null
            if( $app | Get-Member 'VirtualDirectories' )
            {
                "Here is path:"
                $ApplicationDefaults_virtualDirectorySettings["path"]
                $vdir = $app.VirtualDirectories |
                            Where-Object { $_.Path -eq $ApplicationDefaults_virtualDirectorySettings["path"] }
            }
            if( -not $vdir )
            {
                Write-Verbose ('IIS://{0}: creating virtual directory' -f $iisAppPath)
                $vdirs = $app.GetCollection()
                $vdir = $vdirs.CreateElement('virtualDirectory')
                $vdir['path'] = $ApplicationDefaults_virtualDirectorySettings["path"]
                $vdirs.Add( $vdir ) | Out-Null
            }
            foreach($kvp in $ApplicationDefaults_virtualDirectorySettings.GetEnumerator()){ # Key-value pair
                try{$vdir.$($kvp.key) = $kvp.value}
                Catch{$vdir.SetAttributeValue($($kvp.key), $($kvp.value))}
            }
        }

        "Commiting Changes for Application Settings (excl. Security Settings)"
        #Commit Changes
        $app.CommitChanges()

        #Security Settings for this application
        $mgr = New-Object Microsoft.Web.Administration.ServerManager
        $appHostConfig = $mgr.GetApplicationHostConfiguration()
        #$($($mgr2.RootSectionGroup.SectionGroups|where-object -Property name -eq -Value "system.webServer").SectionGroups|where-object -Property name -eq -Value "security")
        $aAuth = $appHostConfig.GetSection("system.webServer/security/authentication/anonymousAuthentication", "$($SiteGroup.name)$($ApplicationDefaultsSettings["path"])")
        foreach($kvp in $Authentication_anonymousAuthenticationSettings.GetEnumerator()){ # Key-value pair
            try{$aAuth.$($kvp.key) = $kvp.value}
            Catch{$aAuth.SetAttributeValue($($kvp.key), $($kvp.value))} # Catch statement is needed as some attributes are stored in "Raw attributes"
            #Cannot use just use what is in the catch statement because what is in the Catch statement is a C# function which requires explicit typing
        }
        $bAuth = $appHostConfig.GetSection("system.webServer/security/authentication/basicAuthentication", "$($SiteGroup.name)$($ApplicationDefaultsSettings["path"])")
        foreach($kvp in $Authentication_basicAuthenticationSettings.GetEnumerator()){ # Key-value pair
            try{$bAuth.$($kvp.key) = $kvp.value}
            Catch{$bAuth.SetAttributeValue($($kvp.key), $($kvp.value))} # Catch statement is needed as some attributes are stored in "Raw attributes"
            #Cannot use just use what is in the catch statement because what is in the Catch statement is a C# function which requires explicit typing
        }
        $wAuth = $appHostConfig.GetSection("system.webServer/security/authentication/windowsAuthentication", "$($SiteGroup.name)$($ApplicationDefaultsSettings["path"])")
        foreach($kvp in $Authentication_windowsAuthenticationSettings.GetEnumerator()){ # Key-value pair
            try{$wAuth.$($kvp.key) = $kvp.value}
            Catch{$wAuth.SetAttributeValue($($kvp.key), $($kvp.value))} # Catch statement is needed as some attributes are stored in "Raw attributes"
            #Cannot use just use what is in the catch statement because what is in the Catch statement is a C# function which requires explicit typing
        }
        $wAuthEP = $wAuth.GetChildElement("extendedProtection")
        foreach($kvp in $Authentication_windowsAuthentication_extendedProtectionSettings.GetEnumerator()){ # Key-value pair
            try{$wAuthEP.$($kvp.key) = $kvp.value}
            Catch{$wAuthEP.SetAttributeValue($($kvp.key), $($kvp.value))} # Catch statement is needed as some attributes are stored in "Raw attributes"
            #Cannot use just use what is in the catch statement because what is in the Catch statement is a C# function which requires explicit typing
        }
        "Commiting Changes for Application's security settings"
        $mgr.CommitChanges()

    }
    Catch{"Failed while Setting Application"    
        throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
    }
}
}


function ES_Setup-ApplicationPools{
param(
    [Parameter(Mandatory=$true)]
    [string]
    # Path to application specifications
    $webAppSettingsXMLPath,
    [Parameter(Mandatory=$false)]
    [string]
    # Location of IIS_schema.xml
    $IIS_schemaXMLPath = "C:\Windows\System32\inetsrv\config\schema\IIS_schema.xml",
    [Parameter(Mandatory=$false)]
    [string]
    # Location of applicationHost.config
    $applicationHostConfigPath = "C:\Windows\System32\inetsrv\config\applicationHost.config"
)

# Obtain default settings for stuff
# Multiple Dictionaries are required because the way IIS stores this information.
$DefaultApplicationPoolDefaultsSettings = @{}
$DefaultProcessModelSettings = @{}
$DefaultRecyclingSettings = @{}
$DefaultRecycling_periodicRestartSettings = @{}
[System.Collections.ArrayList]$DefaultRecycling_periodicRestart_scheduleSettings = @()
$DefaultFailureSettings = @{}
$DefaultCPUSettings = @{}

    # From IIS_schema.xml:
try{
$applicationPoolsInfo = Get-WebSchema -list -fileName $IIS_schemaXMLPath -sectionName system.applicationHost/applicationPools
$ApplicationPoolDefaultsInfo = $applicationPoolsInfo.collection.attribute
#ApplicationPoolDefaults Infos
    #queueLength uint
    #autoStart bool
    #enable32BitApponWin64 bool
    #managedRuntimeVersion string
    #managedRuntimeLoader string
    #enableConfigurationOverride bool
    #managedPipelineMode enum "Integrated", "Classic"
    #CLRConfigFile string
    #passAnonymousToken bool
    #startMode enum "OnDemand", "AlwaysRunning"

foreach($attribute in $ApplicationPoolDefaultsInfo){
    "Name: $($attribute.name)"
    if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
        "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
        $DefaultApplicationPoolDefaultsSettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
    }
    else{"Default VALUE DNE"}
    $attribute.type
}

#ProcessModel Infos:
    #identityType enum "LocalSystem","LocalService", "NetworkService", "SpecificUser", "ApplicationPoolIdentity"
    #username string *** Has no default value
    #password string
    #loadUserProfile
    #setProfileEnvironment bool
    #logonType enum "LogonBatch", "LogonService"
    #manualGroupMembership bool
    #idleTimeout timespan
    #idleTimeoutAction enum "Terminate", "Suspend"
    #maxProcesses uint
    #shutdownTimeLimit timespan
    #startupTimeLimit timespan
    #pingingEnabled bool
    #pingInterval timespan
    #prinResponseTime timespan
    #logEventOnProcessModel flages "IdleTimeout"
#$processModelInfo = $($applicationPoolsInfo.collection.element | Where-Object -Property "name" -eq -Value "processModel").attribute
$processModelInfo = $($applicationPoolsInfo.collection.element | Where-Object{$_.name -eq "processModel"}).attribute
#$applicationPoolsInfo.collection.element | "$_"
foreach($attribute in $processModelInfo){
    "Name: $($attribute.name)"
    if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
        "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
        $DefaultProcessModelSettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
    }
    else{"Default VALUE DNE"}
    $attribute.type
}
    


#Recycling Infos:
    #disallowOverlappingRotation bool
    #disallowRotationOnConfigChange bool
    #logEventonRecycle flags "Time", "Requests", "Schedule", "Memory", "IsapiUnhealth", "OnDemand", "ConfigChange", "PrivateMemory"
    $recyclingInfo = $($applicationPoolsInfo.collection.element | Where-Object{$_.name -eq "recycling"}).attribute

    foreach($attribute in $recyclingInfo){
        "Name: $($attribute.name)"
        if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
            "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
            $DefaultRecyclingSettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
        }
        else{"Default VALUE DNE"}
        $attribute.type
    }   

    
    #periodicRestart Infos:
        #memory uint
        #privateMemory uint
        #requests uint
        #time timespan

        <# There is no default information or information that can be set as default for this (since it's a collection)
        $Recycling_periodicRestartInfo = $($applicationPoolsInfo.collection.element | Where-Object -Property name -eq -Value "recycling").element.attribute

        foreach($attribute in $Recycling_periodicRestartInfo){
            "Name: $($attribute.name)"
            if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
                "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
                $DefaultRecycling_periodicRestartSettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
            }
            else{"Default VALUE DNE"}
            $attribute.type
        }#>


        #schedule Infos:
            #Collection:
                #value timespan   *** does not have a default value in out test setup
        $DefaultRecyling_periodicRestart_scheduleSettings = $($applicationPoolsInfo.collection.element | Where-Object{$_.name -eq "recycling"}).element.element.collection.attribute

        foreach($attribute in $DefaultRecyling_periodicRestart_scheduleSettings){
            "Name: $($attribute.name)"
            if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
                "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
                $DefaultRecycling_periodicRestart_scheduleSettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
            }
            else{"Default VALUE DNE"}
            $attribute.type
        }

#Failure Infos:
    #loadBalancerCapabilities enum "TopLevel", "HttpLevel"
    #orphanWorkerProcess string
    #orphanActionParams string
    #rapidFailProtection bool
    #rapidFailProtectionInterval timespan
    #rapidFailProtectionMaxCrashes uint
    #autoShudownExe string   *** does not have a default value in our test setup
    #autoShutdownParams string  *** does not have a default value in our test setup
    $failureInfo = $($applicationPoolsInfo.collection.element | Where-Object{$_.name -eq "failure"}).element.attribute

    foreach($attribute in $failureInfo){
        "Name: $($attribute.name)"
        if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
            "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
            $DefaultFailureSettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
        }
        else{"Default VALUE DNE"}
        $attribute.type
    }



#CPU Infos:
    #limit uint
    #action enum "NoAction", "KillW3wp", "Throttle", "ThrottleUnderLoad"
    #resetInterval timeSpan
    #smpAffinitiezed bool
    #smpProcessorAffinityMask uint
    #smpProcessorAffinityMask2 uint
    #processorGroup int
    #numaNodeAssignment enum "MostAvailableMemory", "WindowsScheduling"
    #numaNodeAffinityMode enum "Soft", "Hard"
    $cpuInfo = $($applicationPoolsInfo.collection.element | Where-Object{$_.name -eq "cpu"}).attribute

    foreach($attribute in $cpuInfo){
        "Name: $($attribute.name)"
        if( [bool]($attribute.psobject.Properties | where { $_.Name -eq "defaultValue"})){
            "Adding default value: {$($attribute.defaultValue)}  Of Type {$($($attribute.defaultValue).GetType())}"
            $DefaultCpuSettings.Set_Item($attribute.Name, $attribute.defaultValue) #Add value to Dictionary
        }
        else{"Default VALUE DNE"}
        $attribute.type
    }


    # From ApplicationHost.Config
}
Catch{"Failed while obtaining info from IIS_schema.xml"
    throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
}
    #From applicationHost.config
try{
        "Obtaining Values from applicationHost.config"
        [xml]$appHostConfigXML = Get-Content -Path $applicationHostConfigPath

        #$appHostConfigXML

		
        #Setting Values for default Element which is assumed to be ApplicationPoolDefaults
        foreach($Setting in $($appHostConfigXML.configuration.'system.applicationHost'.applicationPools.applicationPoolDefaults.Attributes)){
            if($Setting){
				$Setting.Name
				$Setting.Value
				$DefaultApplicationPoolDefaultsSettings.Set_Item($Setting.Name, $Setting.Value)
			}
        }
		$appHostConfigXML.configuration.'system.applicationHost'.applicationPools.applicationPoolDefaults.attributes
		$($appHostConfigXML.configuration.'system.applicationHost'.applicationPools.applicationPoolDefaults.ApplicationPoolDefaults.Attributes)
        #Setting Values for ApplicationPoolDefaults. This is for in the odd/unexpected event that this info is stored with explicit structure.
        foreach($Setting in $($appHostConfigXML.configuration.'system.applicationHost'.applicationPools.applicationPoolDefaults.ApplicationPoolDefaults.Attributes)){
			if($Setting){
				$Setting.Name
				$Setting.Value
				$DefaultApplicationPoolDefaultsSettings.Set_Item($Setting.Name, $Setting.Value)
			}
        }

        #Setting Values for ProcessModel
        foreach($Setting in $($appHostConfigXML.configuration.'system.applicationHost'.applicationPools.applicationPoolDefaults.processModel.Attributes)){
            if($Setting){
				$Setting.Name
				$Setting.Value
				$DefaultProcessModelSettings.Set_Item($Setting.Name, $Setting.Value)
			}
        }

        #Setting Values for Recycling
        foreach($Setting in $($appHostConfigXML.configuration.'system.applicationHost'.applicationPools.applicationPoolDefaults.recycling.Attributes)){
            if($Setting){
				$Setting.Name
				$Setting.Value
				$DefaultRecyclingSettings.Set_Item($Setting.Name, $Setting.Value)
			}
        }

        #Setting Values for Recycling_periodicRestart
        foreach($Setting in $($appHostConfigXML.configuration.'system.applicationHost'.applicationPools.applicationPoolDefaults.recycling.periodicRestart.Attributes)){
            if($Setting){
				$Setting.Name
				$Setting.Value
				$DefaultRecycling_periodicRestartSettings.Set_Item($Setting.Name, $Setting.Value)
			}
        }

        "Schedule Values from applicationhost.config"
        #Setting Values for Recycling_periodicRestart_schedule   HANDLED differently because this is a collection.
        foreach($Setting in $($appHostConfigXML.configuration.'system.applicationHost'.applicationPools.applicationPoolDefaults.recycling.periodicRestart.schedule.add)){
            if($Setting){
				$Setting.Value
				"Added entry $($DefaultRecycling_periodicRestart_scheduleSettings.add($Setting.Value))"
			}
        }
        <#
        foreach($Setting in $($appHostConfigXML.configuration.'system.applicationHost'.applicationPools.applicationPoolDefaults.recycling.periodicRestart.schedule.add)){
            $Setting.Value
            "Added entry $($DefaultRecycling_periodicRestart_scheduleSettings.add($Setting.Value))"
        }
        #>

        #Setting Values for Failure
        foreach($Setting in $($appHostConfigXML.configuration.'system.applicationHost'.applicationPools.applicationPoolDefaults.Failure.Attributes)){
            if($Setting){
				$Setting.Name
				$Setting.Value
				$DefaultFailureSettings.Set_Item($Setting.Name, $Setting.Value)
			}
        }

        #Setting Values for CPU
        foreach($Setting in $($appHostConfigXML.configuration.'system.applicationHost'.applicationPools.applicationPoolDefaults.CPU.Attributes)){
            if($Setting){
				$Setting.Name
				$Setting.Value
				$DefaultCPUSettings.Set_Item($Setting.Name, $Setting.Value)
			}
        }

    }
Catch{"Failed while obtaining info from ApplicationHost.Config"    
    throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
}



"Obtaining Values from webAppSettings.xml"
[xml]$appPoolsConfigXML = Get-Content -Path $webAppSettingsXMLPath

#Foreach AppPool:
foreach($AppPoolConfig in $($appPoolsConfigXML.WebAppSettings.applicationPools.add)){
    # Copy Dictionaries
    $ApplicationPoolDefaultsSettings = $DefaultApplicationPoolDefaultsSettings.PsObject.Copy()
    $ProcessModelSettings = $DefaultProcessModelSettings.PsObject.Copy()
    $RecyclingSettings = $DefaultRecyclingSettings.PsObject.Copy()
    $Recycling_periodicRestartSettings = $DefaultRecycling_periodicRestartSettings.PsObject.Copy()
    $Recycling_periodicRestart_scheduleSettings = $DefaultRecycling_periodicRestart_scheduleSettings.PsObject.Copy()
    $FailureSettings = $DefaultFailureSettings.PsObject.Copy()
    $CPUSettings = $DefaultCPUSettings.PsObject.Copy()


# modify dictionary with overwrite values for App Pool
    "Overwriting default settings with settings from applicationPools.xml"
                                                                                                                                                                                                                    try{
    #Setting Values for default Element which is assumed to be ApplicationPoolDefaults
    foreach($Setting in $($appPoolConfig.Attributes)){
        if($Setting){
			$Setting.Name
			$Setting.Value
			$ApplicationPoolDefaultsSettings.Set_Item($Setting.Name, $Setting.Value)
		}
    }
    #Setting Values for ApplicationPoolDefaults. This is for the event that this info is stored with explicit structure.
    foreach($Setting in $($appPoolConfig.ApplicationPoolDefaults.Attributes)){
        if($Setting){
			$Setting.Name
			$Setting.Value
			$ApplicationPoolDefaultsSettings.Set_Item($Setting.Name, $Setting.Value)
		}
    }

    #Setting Values for ProcessModel
    foreach($Setting in $($appPoolConfig.processModel.Attributes)){
        if($Setting){
			$Setting.Name
			$Setting.Value
			$ProcessModelSettings.Set_Item($Setting.Name, $Setting.Value)
		}
    }

    #Setting Values for Recycling
    foreach($Setting in $($appPoolConfig.recycling.Attributes)){
        if($Setting){
			$Setting.Name
			$Setting.Value
			$RecyclingSettings.Set_Item($Setting.Name, $Setting.Value)
		}
    }

    #Setting Values for Recycling_periodicRestart
    foreach($Setting in $($appPoolConfig.recycling.periodicRestart.Attributes)){
        if($Setting){
			$Setting.Name
			$Setting.Value
			$Recycling_periodicRestartSettings.Set_Item($Setting.Name, $Setting.Value)
		}
    }

    "Schedule Values from appplicationPools.xml"
    if($($appPoolConfig.recycling.periodicRestart.schedule.add)){
        "Schedule Values specified by applicationPools.xml, clearing default values."
        $Recycling_periodicRestart_scheduleSettings.clear()
    }
    #Setting Values for Recycling_periodicRestart_schedule   HANDLED differently because this is a collection.
    foreach($Setting in $($appPoolConfig.recycling.periodicRestart.schedule.add)){
        if($Setting){
			$Setting.Value
			"Added entry $($Recycling_periodicRestart_scheduleSettings.add($Setting.Value))"
		}
    }

    #Setting Values for Failure
    foreach($Setting in $($appPoolConfig.Failure.Attributes)){
        if($Setting){
			$Setting.Name
			$Setting.Value
			$FailureSettings.Set_Item($Setting.Name, $Setting.Value)
		}
    }

    #Setting Values for CPU
    foreach($Setting in $($appPoolConfig.CPU.Attributes)){
        if($Setting){
		$Setting.Name
        $Setting.Value
        $CPUSettings.Set_Item($Setting.Name, $Setting.Value)
		}
    }
    }
    Catch{"Failed while obtaining info from ApplicationPools.xml"    
        throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"}

    #Set all values of an Application Pool to the dictionary's values. Create App Pool if needed.
    "Setting Values"
    try{
        if( -not (Test-IisAppPool -Name $ApplicationPoolDefaultsSettings["name"]) )
        {
            Write-Verbose ('Creating IIS Application Pool {0}' -f $ApplicationPoolDefaultsSettings["name"])
            $mgr = New-Object 'Microsoft.Web.Administration.ServerManager'
            $appPool = $mgr.ApplicationPools.Add($ApplicationPoolDefaultsSettings["name"])
            $mgr.CommitChanges()
        }

        $appPool = Get-IisAppPool -Name $ApplicationPoolDefaultsSettings["name"]

        foreach($kvp in $ApplicationPoolDefaultsSettings.GetEnumerator()){ # Key-value pair
            try{$appPool.$($kvp.key) = $kvp.value}
            Catch{$appPool.SetAttributeValue($($kvp.key), $($kvp.value))} # Catch statement is needed as some attributes are stored in "Raw attributes"
            #Cannot use just use what is in the catch statement because what is in the Catch statement is a C# function which requires explicit typing
        }
        foreach($kvp in $ProcessModelSettings.GetEnumerator()){ # Key-value pair
            #$key = $kvp.Key
            #$val = $kvp.Value
            try{$AppPool.ProcessModel.$($kvp.key) = $kvp.value}
            Catch{$appPool.ProcessModel.SetAttributeValue($($kvp.key), $($kvp.value))}
        }

        foreach($kvp in $RecyclingSettings.GetEnumerator()){ # Key-value pair
            #$key = $kvp.Key
            #$val = $kvp.Value
            $AppPool.Recycling.$($kvp.key) = $kvp.value
            #Catch{$appPool.Recycling.SetAttributeValue($($kvp.key), $($kvp.value))} # not needed
        }

        foreach($kvp in $Recycling_periodicRestartSettings.GetEnumerator()){ # Key-value pair
            #$key = $kvp.Key
            #$val = $kvp.Value
            $AppPool.Recycling.PeriodicRestart.$($kvp.key) = $kvp.value
        }
        "Adding these scheduled times."
        $AppPool.Recycling.PeriodicRestart.Schedule.clear() # Clear all currently existing values. Defaults values will be re-added if no values specified by applicationpools.xml
        foreach($value in $Recycling_periodicRestart_scheduleSettings.GetEnumerator()){ #This is just an array
            $AppPool.Recycling.PeriodicRestart.Schedule.add($value)
        }

        foreach($kvp in $FailureSettings.GetEnumerator()){ # Key-value pair
            #$key = $kvp.Key
            #$val = $kvp.Value
            $AppPool.Failure.$($kvp.key) = $kvp.value
        }

        foreach($kvp in $CPUSettings.GetEnumerator()){ # Key-value pair
            #$key = $kvp.Key
            #$val = $kvp.Value
            try{$AppPool.CPU.$($kvp.key) = $kvp.value}
            Catch{$appPool.CPU.SetAttributeValue($($kvp.key), $($kvp.value))}
        }
        "Commiting Changes"
        #Commit Changes
        $appPool.CommitChanges()
    }
    Catch{"Failed while Setting ApplicationPool"    
        throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
    }

}
}



