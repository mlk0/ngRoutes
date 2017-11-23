function loadconfig([string]$configpath) {
	$global:appSettings = @{}
	$config = [xml](get-content "$configpath")
	$global:appSettings["logConfigFilePath"] = "$configpath"
	if ($config.configuration.appSettings) {
		foreach ($addNode in $config.configuration.appSettings.add) {
			if ($addNode.Value.Contains(‘,’)) {
				# Array case
				$value = $addNode.Value.Split(‘,’)
				for ($i = 0; $i -lt $value.length; $i++) { 
					$value[$i] = $value[$i].Trim() 
				}
			} else {
				# Scalar case
				$value = $addNode.Value
			}
			$global:appSettings[$addNode.Key] = $value
		}
	}
}

function configure-logging([string]$log4netdllpath) {
	Add-Type -Path $log4netdllpath
	$global:logger =  [log4net.LogManager]::GetLogger("PowerShell")
	$global:mylog = [log4net.LogManager]::GetLogger("root")
	if ( (test-path $appSettings["logConfigFilePath"]) -eq $false) {
		$message = "WARNING: logging config file not found: " +  $appSettings["logConfigFilePath"]
		write-host
		write-host $message -foregroundcolor yellow
		write-host
	} else {
		$configFile = new-object System.IO.FileInfo( $appSettings["logConfigFilePath"] )
		$xmlConfigurator = [log4net.Config.XmlConfigurator]::ConfigureAndWatch($configFile)
	}
}

function log-info ([string] $message) {
	write-host $message
	$logger.Info($message);
}

function log-warn ([string] $message) {
	write-host "WARNING: $message" -foregroundcolor yellow
	$logger.Warn($message);
}

function log-error ([string] $message) {
	write-host "ERROR: $message" -foregroundcolor red
	$logger.Error($message);
}

function startup() {
	$scriptPath = (Get-Item -Path ".\" -Verbose).FullName
	loadconfig "$scriptPath\log4net.config"
	configure-logging "$scriptPath\log4net.dll"
	Write-Host "Logger configuration complete"
}

startup