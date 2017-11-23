#Enum for log
$errorTypeEnum = " 
namespace ErrorTypes 
{ 
    public enum ErrorType 
    { 
        Info, 
        Error, 
        Warn
    } 
} 
"
Add-Type -TypeDefinition $errorTypeEnum -Language CSharpVersion3

#declaring data
function Datadeclaration([string]$ConfigPath)
{

    Try { 
    $siteApppoolName=  "TestPool"
    $iisAppPoolDotNetVersion="v4.0"
    $enable32bit="TRUE"
    $username=""
    $password=""
    $identityType="ApplicationPoolIdentity"
    $appPath=""   
    $sitePath= ""       
    $appApppoolName = "" 
    $arrayConfig = @(".xml",".json")
   
    [hashtable]$HashConfigValue = @{}   #Create a hashtable variable 

    $ConfigPath=$ConfigPath+$arrayConfig[0]
    If(-not(Test-Path -path $ConfigPath))       #check whether config file exist or not
    {
        $ConfigPath=$ConfigPath.Replace($arrayConfig[0],$arrayConfig[1])

        if(-not(Test-Path -path $ConfigPath))
        {
            $error ="Please create config file"
            Write-Host $error -ForegroundColor Green
            throw $error
        }      
    }

    if($ConfigPath.EndsWith('.xml'))
    {
         [xml]$file=get-content $ConfigPath         #take the config file
    }
    else
    {
         $file = (Get-Content $ConfigPath -Raw) | ConvertFrom-Json
    }

    if(![string]::IsNullOrEmpty($file.configdata.logPath))        #check whether error log file exist or not
    {
         $Global:logPath=$file.configdata.logPath      # overwrite the LogPath value from config file.if we didnt give global the renamed value will not be reflected
    }

    $Message="Hosting website Started at {0}" -f (Get-Date).ToString("yyyy MMM d h:m:s")  

    Log $Message ([ErrorTypes.ErrorType]::Info)

    Write-Host $Message  -ForegroundColor Green


    if(![string]::IsNullOrEmpty($file.configdata.siteApppoolName))       
    {  
        $HashConfigValue.siteApppoolName = $file.configdata.siteApppoolName             #Take pool name from config file and added to hash table
    } else {
        $HashConfigValue.siteApppoolName = $siteApppoolName         #Take default value
    }


    if(![string]::IsNullOrEmpty($file.configdata.iisAppPoolDotNetVersion))    
    {
        $HashConfigValue.iisAppPoolDotNetVersion = $file.configdata.iisAppPoolDotNetVersion
    }else {
         $HashConfigValue.iisAppPoolDotNetVersion = $iisAppPoolDotNetVersion        #Take default value
    }

    if(![string]::IsNullOrEmpty($file.configdata.enable32bit))    
    {
        $HashConfigValue.enable32bit =$file.configdata.enable32bit
    }else{
        $HashConfigValue.enable32bit = $enable32bit
    }

    if([string]::IsNullOrEmpty($file.configdata.sitename) -or [string]::IsNullOrEmpty($file.configdata.Port) -or [string]::IsNullOrEmpty($file.configdata.applicationName))    
    {
       $error="Please specify Sitename,Port and application name in config file"

       Write-Host $error -ForegroundColor White

       throw $error
    }
    else
    {
        $HashConfigValue.siteName =$file.configdata.sitename
        $HashConfigValue.Port = $file.configdata.Port
        $HashConfigValue.appName = $file.configdata.applicationName
    }

    if(![string]::IsNullOrEmpty($file.configdata.apppoolUsername))    
    {
         $HashConfigValue.username =$file.configdata.apppoolUsername
    }else{
          $HashConfigValue.username = $username
    }

    if(![string]::IsNullOrEmpty($file.configdata.apppoolPassword))    
    {
          $HashConfigValue.password =$file.configdata.apppoolPassword
    }else{
          $HashConfigValue.password = $password
    }

    if(![string]::IsNullOrEmpty($file.configdata.identityType))    
    {
          $HashConfigValue.identityType =$file.configdata.identityType
    }else{
          $HashConfigValue.identityType = $identityType
    }

    if(![string]::IsNullOrEmpty($file.configdata.applicationPath))    
    {
          $HashConfigValue.appPath = $file.configdata.applicationPath
    } else{
          $HashConfigValue.appPath = $appPath
    }


    if(![string]::IsNullOrEmpty($file.configdata.applicationApppoolName))    
    {
          $appApppoolName=$file.configdata.applicationApppoolName
    }
    else
    {
          $appApppoolName=$file.configdata.siteApppoolName
    }
    $HashConfigValue.appApppoolName = $appApppoolName


    if([string]::IsNullOrEmpty($file.configdata.sitePath))    
    {
        $Message="Please enter site path in configuration file" 

        Log $Message ([ErrorTypes.ErrorType]::Warn)

        throw
    }
    else
    {
         $sitePath=$file.configdata.sitePath

         $HashConfigValue.sitePath = $sitePath

         If(-not(Test-Path -path $sitePath))
         {
           $Message="Site path specified is not correct"

           Log $Message ([ErrorTypes.ErrorType]::Warn)

           throw
         }
    }

    #Return the hashtable
    Return $HashConfigValue 

 }      
 Catch [System.Exception]{

        $lineno=$_.InvocationInfo.ScriptLineNumber

        $error ="Problem in configuration file reading at line number $($lineno)"

        throw $error
 }

}

#create app pool
function CreateAppPool([string]$apppoolName,[hashtable]$HashConfigValue)
{
    
 
    Import-Module WebAdministration    
    cd IIS:\AppPools      #change the directory

    if(!(Test-Path $apppoolName)) #check if pool is already exist
    {
        $apppool = New-Item $apppoolName #app pool created
        $apppool.managedRuntimeVersion = $HashConfigValue.iisAppPoolDotNetVersion    # Assign App Pool Version
        $apppool.enable32BitAppOnWin64 = $HashConfigValue.enable32bit  
        if(![string]::IsNullOrEmpty($HashConfigValue.username) -or ![string]::IsNullOrEmpty($HashConfigValue.password))       
        { 
            $apppool.processModel.userName = $HashConfigValue.username
            $apppool.processModel.password = $HashConfigValue.password
            $apppool.processModel.identityType=3
        } 
        else
        {
            $apppool.processModel.identityType = $HashConfigValue.identityType
        } 
       
        $appPool.managedPipeLineMode = "Integrated"        
        $apppool|Set-Item

        $Message="AppPool created successfully with name {0}" -f $apppoolName

        Log $Message ([ErrorTypes.ErrorType]::Info)

        Write-Host $Message -ForegroundColor Green
    }
    else 
    {
          $Error = "Already Exist AppPool {0}" -f $apppoolName           #error message

          Log $Error ([ErrorTypes.ErrorType]::Warn)

          Write-Host $Error -ForegroundColor Green        
    }   
}

#create site
function CreateSite([hashtable]$HashConfigValue)
{ 

    cd IIS:\Sites\

    if(!(Test-Path $HashConfigValue.sitename)) 
    {

        #check whether the binding is already using
        $Websites = Get-ChildItem IIS:\Sites
        foreach ($Site in $Websites) {

            $Binding = $Site.bindings

            [string]$BindingInfo = $Binding.Collection      
             
            [string]$sitePort = $BindingInfo.SubString($BindingInfo.IndexOf(":")+1,$BindingInfo.LastIndexOf(":")-$BindingInfo.IndexOf(":")-1) 

            if($sitePort -eq $HashConfigValue.port)
            {
                $Error = "Already using port number" -f $HashConfigValue.sitename     #error message       

                throw $Error
            }
        }

        $port=$HashConfigValue.port

        New-Item $HashConfigValue.sitename -bindings @{protocol="http";bindingInformation=":${port}:"} -physicalPath $HashConfigValue.sitePath  #create site
    
        Set-ItemProperty $HashConfigValue.sitename -Name applicationpool -Value $HashConfigValue.siteApppoolName        #set application pool for that site

        $Message="Site hosted successfully with name {0}" -f $HashConfigValue.sitename

        Log $Message ([ErrorTypes.ErrorType]::Info)

        Write-Host $Message -ForegroundColor Green 

    }
    else
    {

         $Error = "Already Exist Site  with name {0}" -f $HashConfigValue.sitename     #error message    

         Log $Error ([ErrorTypes.ErrorType]::Warn)

         Write-Host $Error -ForegroundColor Green 
         
         throw   
    } 

}

#create application
function CreateApplication([hashtable]$HashConfigValue)
{
 Try { 
      $sitename=$HashConfigValue.sitename

      cd IIS:\Sites\$sitename

      New-Item $HashConfigValue.appName  -physicalPath $HashConfigValue.appPath -type Application #create site  

      if($HashConfigValue.siteApppoolName -ne $HashConfigValue.appApppoolName) 
      {
         CreateAppPool $HashConfigValue.appApppoolName $xmlinfo
      }  

      cd IIS:\Sites\$sitename

      Set-ItemProperty $HashConfigValue.appName -Name applicationpool -Value $HashConfigValue.appApppoolName    

      $Message="Application hosted successfully with name {0}" -f $HashConfigValue.appName

      Log $Message ([ErrorTypes.ErrorType]::Info)

      Write-Host $Message -ForegroundColor Green

       }      
 Catch [System.Exception]{

        $lineno=$_.InvocationInfo.ScriptLineNumber
        $error ="Error in CreateApplication at line number $($lineno)"
        throw $error
 }  
}

#Logging errors,warning,info
function Log([string]$errorMessage,[ErrorTypes.ErrorType]$Errortype)
{
      If(-not(Test-Path -path $Global:logPath.substring(0,$Global:logPath.LastIndexOf("\")))) 
      {
          $error="Error log path is not correct"

          Write-Host $error -ForegroundColor White

          throw $error
      }

      add-content -Path $Global:logPath -Value "$((Get-Date).ToString("yyyy MM dd hh:mm:ss"))  :  $($Errortype)  -  $($errorMessage)"
        
}





