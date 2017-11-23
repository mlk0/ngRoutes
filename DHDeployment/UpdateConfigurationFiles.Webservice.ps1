##
##Param(
#	[string]$DevDBServer = "10.32.28.243|ZEBRADB-DM13-TOR",
#	[string]$TargetDBServer = "10.32.28.243|10.32.28.243",
#	[string]$DevDBs = "DHPortal|DHSystemConfiguration|CommentManagement|Zebra",
#	[string]$TargetDBs = "DHPortal|DHSystemConfiguration|CommentManagement|Zebra",
#	[string]$DevHostNames = "",
#	[string]$TargetHostNames = "",
#	[string]$OctopusOriginalPackageDirectoryPath="\\10.32.28.232\c$\Octopus\Applications\DITDev\Orchard.Web\1.7.13.0_3",
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
    $regex = [regex] '__(\w+?)__'
	Select-String -path $file -pattern $regex -AllMatches | Foreach-object {
		for ($i=0; $i -lt $_.matches.count;$i++) {
			$word = $($_.matches[$i]) -replace "__",""
           # log-info "This is the word: $word"
           # log-info "This is is the TokenList: $TokenList"
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
					log-warn "($OctopusEnvironmentName) Warning: The token '$word' does not have an Octopus variable assigned to it"
				}
			} else {
				log-info "($OctopusEnvironmentName) $word is already in the list of tokens"
			}
		}
	}

	log-info "`tContents of Tokens: $Tokens"
	
	if ($Tokens) {
		UpdateConfigFile $file $Tokens $TokenValues "$filename"
	} else {
		log-info "No Tokens to update in $filename"
	}
}

# Get list of config files
$CurrentPath=$OctopusOriginalPackageDirectoryPath

$List = Get-ChildItem -Path "$CurrentPath" -Recurse | where {$_.extension -eq ".config"} | select fullname, name
foreach ($file in $List)
{
	tokenupdate $($file.fullname) $($file.name)
}
