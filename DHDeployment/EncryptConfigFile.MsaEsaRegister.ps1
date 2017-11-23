. ./common_functions.ps1

# Check if logging function available
if ( $null -eq $global:appSettings) {
	write-output "Logging functions not loaded. Loading it now."
	push-location "$BuildToolsPath\Logging"
	. .\LoggingFunctions.ps1
	pop-location
}

#start of encription process
$Regiis_EXE = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe"
log-info "($OctopusEnvironmentName) Running config file encryption process for $Targetpath"
if (Test-Path $TargetPath\MsaEsaRegister.exe.config) {

    # Copy MsaEsaRegister.exe.config to web.config
	if (Copy-Item $TargetPath\MsaEsaRegister.exe.config -Destination $TargetPath\web.config) {
		log-error "Error copying MsaEsaRegister.exe.config for $Targetpath"
		throw "Error copying MsaEsaRegister.exe.config for $Targetpath"
	}

	& $Regiis_EXE -pef 'appSettings' $TargetPath -prov DataProtectionConfigurationProvider

	# Copy encrypted web.config back to MsaEsaRegister.exe.config
	Copy-Item $TargetPath\web.config -Destination $TargetPath\MsaEsaRegister.exe.config

}
else {
	log-error "($OctopusEnvironmentName) file $TargetPath\MsaEsaRegister.exe.config does not exist"
	throw "($OctopusEnvironmentName) file $TargetPath\MsaEsaRegister.exe.config does not exist"
}
log-info "($OctopusEnvironmentName) Finished config file encryption process for $Targetpath"
