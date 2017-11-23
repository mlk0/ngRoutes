Param(
    $ApiKey,
    [string]$ProjectName,
    [string]$AutoDeployEnvironments,
    [string]$BuildNumber,
    [string]$ReleaseNotes,
    [string]$NuGetPackageNames,
    [string]$ReleaseNotesPath
)
<#
https://github.com/OctopusDeploy/OctopusDeploy-Api/blob/master/REST/PowerShell/Deployments/CreateReleaseAndDeployment.ps1 
was used as reference material for creating this script.

"Octopus Deploy is a user-friendly automated deployment tool for .NET developers. 
This GitHub repository exists to provide documentation for the Octopus Deploy HTTP API." 
- https://github.com/OctopusDeploy/OctopusDeploy-Api/wiki


#>

# If there is an error in the script, cause VSTS to see the error and stop
$ErrorActionPreference = "Stop"

##CONFIG##

#$ApiKey = "" #Octopus API Key --Passed as variable from VSTS
#"$ApiKey is redacted by VSTS"
$OctopusURL = "http://octopus.dhltd.com/" #Octopus URL  -- Should we hardcode this or take as a variable from VSTS?
#$ProjectName = "" #Passed as variable from VSTS
    # VSTS has a system variable called SYSTEM_TEAMPROJECT that stores the name of the team project for a build.
    # If we have things setup s.t. the Octopus Project has the same name as the VSTS Project, we could use this variable.
    # Else, we will need to create a VSTS variable containing the Octopus Project name. (We do this.)
"Octopus Project Name is: $ProjectName"
#$AutoDeployEnvironments   --Should be passed as variable from VSTS
#$AutoDeployEnvironments = $OctopusAutomaticDeployEnvironments
"Auto Deploy Environments are: $AutoDeployEnvironments"
#$NuGetPackageNames = "" #Passed as variable from VSTS

##PROCESS##

$Header =  @{ "X-Octopus-ApiKey" = $ApiKey }
 
#Getting Project By Name
$retryCount = 0
Do{
    try{
    $retryCount++
    $Project = Invoke-WebRequest -UseBasicParsing -Uri "$OctopusURL/api/projects/$ProjectName" -Headers $Header| ConvertFrom-Json
    break
    } catch{

        Write-Warning "Octopus Rest API Call Failed. Try Number $retryCount"
        "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
        if($retryCount -eq 3){
            throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
        }
    }
} #End of Do
Until($retryCount -eq 3)

#$Project
#$Project.LifecycleId


#Getting all Environments by Name   
$retryCount = 0
Do{
    try{
    $retryCount++
    $Environments = Invoke-WebRequest -UseBasicParsing -Uri "$OctopusURL/api/Environments/all" -Headers $Header| ConvertFrom-Json
    break
    } catch{

        Write-Warning "Octopus Rest API Call Failed. Try Number $retryCount"
        "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
        if($retryCount -eq 3){
            throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
        }
    }
} #End of Do
Until($retryCount -eq 3)



try{# Check if deploy environments specified by autoDeployEnvironments exist and are valid if they exist.
# Get Project(HAVE)->GetLifecycleID->GetLifecycle->GetEnvironment IDs for phase 1->Get environment names->Compare with autoDeployEnvironments provided
# Assumes that the first phase in the lifecyle is "phase one" as there is no other identifying information provided in the JSON containing info on Lifecycles.
    
    if($AutoDeployEnvironments){
        #Getting all information on project's lifecycle  
        $retryCount = 0
        Do{
            try{
            $retryCount++
            $ProjectLifecycle = Invoke-WebRequest -UseBasicParsing -Uri "$OctopusURL/api/lifecycles/$($Project.LifecycleId)" -Headers $Header| ConvertFrom-Json
            break
            } catch{

                Write-Warning "Octopus Rest API Call Failed. Try Number $retryCount"
                "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
                if($retryCount -eq 3){
                    throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
                }
            }
        } #End of Do
        Until($retryCount -eq 3)
        
        $ValidEnvironmentIDs = $ProjectLifecycle.Phases[0].AutomaticDeploymentTargets # AFAIK we don't actually ever use this feature of Octopus for our autodeploy. Going to have this anyways
        $ValidEnvironmentIDs += $ProjectLifecycle.Phases[0].OptionalDeploymentTargets
        #$ValidEnvironmentIDs

        $ValidEnvironmentNames = @()
        foreach($EnvironmentID in $ValidEnvironmentIDs){
            $ValidEnvironmentNames += ($Environments | ?{$_.Id -eq $EnvironmentID}).name
        }
        "Valid Environments for automated deployment:"
        $ValidEnvironmentNames

        # Check if each deploy environment exists.
        foreach($EnvironmentName in $AutoDeployEnvironments.Split(';')){
            if($ValidEnvironmentNames -contains $EnvironmentName){"$EnvironmentName is a valid environment for automated deployment."}
            else{
                throw "$EnvironmentName is not a valid environment for deployment. It is likely your autoDeployEnvironments variable has an incorrect value."
            }
        }
    }
}Catch{throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"}

#Getting Deployment Template to get Next version 
$retryCount = 0
Do{
    try{
    $retryCount++
    $dt = Invoke-WebRequest -UseBasicParsing -Uri "$OctopusURL/api/deploymentprocesses/deploymentprocess-$($Project.id)/template" -Headers $Header | ConvertFrom-Json 
    break
    } catch{

        Write-Warning "Octopus Rest API Call Failed. Try Number $retryCount"
        "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
        if($retryCount -eq 3){
            throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
        }
    }
} #End of Do
Until($retryCount -eq 3)


#Creating Release
$SelectedPackages = "" #List of which packages to include in a release. Formatted to match REST API requirements when added to $ReleaseBody.
foreach($Package in $NuGetPackageNames.split(';')){
    $SelectedPackages += "{`"StepName`":`"$Package`",`"Version`" : `"$($BuildNumber)`"},"
}
$SelectedPackages = $SelectedPackages.Substring(0,$SelectedPackages.Length-1) # Remove last ',' to obtain correct formatting.

$ReleaseNotes


#$releaseNotesPath
$ReleaseNotesString = Get-Content $releaseNotesPath -Raw
$ReleaseNotesString = $ReleaseNotesString.Replace("`"","&quot;") # Required to prevent API call errors.
#Release notes are now grabbed from file as the Microsoft created function Generate Release Notes does not properly output ReleaseNotes as an Octopus Variable. Also, the API doesn't like the '"' character in the release notes.

$ReleaseBody =  @"
{ 
    "Projectid" : "$($Project.Id)",
    "Version" : "$($BuildNumber)",
    "SelectedPackages" :[$SelectedPackages],
    "ReleaseNotes" : "$($ReleaseNotesString)"
}
"@

"Json Release body used to create release via RESTAPI:"
$ReleaseBody

$retryCount = 0
Do{
    try{
    $retryCount++
    $r = Invoke-WebRequest -UseBasicParsing -Uri $OctopusURL/api/releases -Method Post -Headers $Header -Body $ReleaseBody | ConvertFrom-Json
    break
    } catch{

        Write-Warning "Octopus Rest API Call Failed. Try Number $retryCount"
        "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
        if($retryCount -eq 3){
            throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
        }
    }
} #End of Do
Until($retryCount -eq 3)



<# This is done earlier because we want to ensure that deploy targets are valid before creating a release.
#Getting all Environments by Name
$retryCount = 0
Do{
    try{
    $retryCount++
    $Environments = Invoke-WebRequest -UseBasicParsing -Uri "$OctopusURL/api/Environments/all" -Headers $Header| ConvertFrom-Json
    break
    } catch{

        Write-Warning "Octopus Rest API Call Failed. Try Number $retryCount"
        "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
        if($retryCount -eq 3){
            throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
        }
    }
} #End of Do
Until($retryCount -eq 3)
#>


#Creating deployment
if($AutoDeployEnvironments){
    foreach($EnvironmentName in $AutoDeployEnvironments.Split(';')){
        "Deploying to: $EnvironmentName"
        $Environment = $Environments | ?{$_.name -eq $EnvironmentName}
        $DeploymentBody = @{ 
                ReleaseID = $r.Id #mandatory
                EnvironmentID = $Environment.id #mandatory
            } | ConvertTo-Json
         $retryCount = 0
        Do{
            try{
            $retryCount++
            $d = Invoke-WebRequest -UseBasicParsing -Uri $OctopusURL/api/deployments -Method Post -Headers $Header -Body $DeploymentBody
            break
            } catch{

                Write-Warning "Octopus Rest API Call Failed. Try Number $retryCount"
                "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
                if($retryCount -eq 3){
                    throw "$($_.Exception.Message) `n $($_.InvocationInfo.PositionMessage)"
                }
            }
        } #End of Do
        Until($retryCount -eq 3)
    }
}
