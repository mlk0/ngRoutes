##
##Param(
#	[string]$DevDBServer = "10.32.28.243|ZEBRADB-DM13-TOR",
#	[string]$TargetDBServer = "10.32.28.243|10.32.28.243",
#	[string]$DevDBs = "DHPortal|DHSystemConfiguration|CommentManagement|Zebra",
#	[string]$TargetDBs = "DHPortal|DHSystemConfiguration|CommentManagement|Zebra",
#	[string]$DevHostNames = "",
#	[string]$TargetHostNames = "",
	#[string]$OctopusOriginalPackageDirectoryPath="\\10.32.28.232\c$\Octopus\Applications\DITDev\Orchard.Web\1.7.13.0_3"
#	[string]$OctopusEnvironmentName="DITDev"
#)
. ./common_functions.ps1
# Check if logging function available
if ( $null -eq $global:appSettings) {
	write-output "Logging functions not loaded. Loading it now."
	push-location "$BuildToolsPath\Logging"
	. .\LoggingFunctions.ps1
	pop-location
}

function tokenupdate([string]$file, [string]$filename) {
	log-info "($OctopusEnvironmentName) Updating $file"
	[string]$Tokens = ""
	[string]$TokenValues = ""
	[string]$TokenList = ""

	$ErrorActionPreference= 'silentlycontinue'
	Select-String -path $file -pattern '__(\w+?)__' -AllMatches | Foreach-object {
		for ($i=0; $i -lt $_.matches.count;$i++) {
			$word = $($_.matches[$i]) -replace "__",""

			if ( $TokenList -notmatch "$word" ) {
				$TokenList = "$TokenList|$word"
				if ( $word -eq "DynamicPdfLicenseKey" ) {
					$tmp = Get-Variable -Name $env:computername -ValueOnly
				} else {
					$tmp = Get-Variable -Name $word -ValueOnly
				}
				
				if ($tmp) {
					log-info "`t $word = $tmp"
					[string]$token, [string]$tokenvalue = $tmp -split "\|"
					if ("$Tokens" -eq "") {
						$Tokens = "$token"
						$TokenValues = "$tokenvalue"
					} else {
						$Tokens = "$Tokens|$token"
						$TokenValues = "$TokenValues|$tokenvalue"
					}
				} else {
					throw "($OctopusEnvironmentName) Error: The token '$word' does not have an Octopus variable assigned to it"
				}
			} else {
				log-info "($OctopusEnvironmentName) $word is already in the list of tokens"
			}
		}
	}

	log-info "`tContents of Tokens: $Tokens"
	
	if ($Tokens) {
		if ($filename -like "*.bat")  {
			UpdateConfigFileDB "$file" "$Tokens" "$TokenValues" "$filename"
		} else {
			UpdateConfigFile "$file" "$Tokens" "$TokenValues" "$filename"
		}	
		
		rename-item $file $($file -replace "Template","$($($OctopusEnvironmentName -replace $Project_Prefix,'') -replace 1,$DBSuffix)")

	} else {
		log-info "No Tokens to update in $file"
	}
}


# Get list of config files
$CurrentPath=$OctopusOriginalPackageDirectoryPath

$List = Get-ChildItem -Path "$CurrentPath" -Recurse | where {$_.extension -eq ".config"}  | select fullname, name


foreach ($file in $List)
{
    if(![string]::IsNullOrEmpty($file.fullname) -and ![string]::IsNullOrEmpty($file.fullname.Trim()))
    {
	    log-info "$($file.fullname)"
 	    tokenupdate $($file.fullname) $($file.name)
	}
}

$List = Get-ChildItem -Path "$CurrentPath" -Recurse | where {$_.extension -eq ".sql"}  | select fullname, name


foreach ($file in $List)
{
    if(![string]::IsNullOrEmpty($file.fullname) -and ![string]::IsNullOrEmpty($file.fullname.Trim()))
    {
	    log-info "$($file.fullname)"
 	    tokenupdate $($file.fullname) $($file.name)
	}
}

# Get UpdateDatabase_Template bat file
#$CurrentPath=$OctopusOriginalPackageDirectoryPath
#$batfile = Get-ChildItem -Path "$CurrentPath\EvnDeploymentCommands" | where {$_.extension -eq ".bat"} | select fullname, name
#tokenupdate $($batfile.fullname) $($batfile.name)
#rename-item $batfile "$configfile.bat"



