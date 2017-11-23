@ECHO off
@SETLOCAL
@SET CHAINEDCALL=false
@SET SONAR=true
@SET UTC=false
@FOR %%A IN (%*) DO @IF "%%A"=="chain" @SET CHAINEDCALL=true
@FOR %%A IN (%*) DO @IF "%%A"=="nosonar" @SET SONAR=false
@FOR %%A IN (%*) DO @IF "%%A"=="noutc" @SET UTC=false
@SET SOLU=%1
@SET SOLUPATH=%2
@SET KEY=%3
@SET VALUE=%4
@SET VERSION=%5
@SET SONARRUNNER=%6
@SET SCRIPTDIRECTORY=%7
@SET JAVA_HOME=C:\Program Files\Java\jre1.8.0_131
  
@CD /D %SOLUPATH%
 
@reg.exe query "HKLM\SOFTWARE\Microsoft\MSBuild\ToolsVersions\14.0" /v MSBuildToolsPath > nul 2>&1
@IF ERRORLEVEL 1 (
@FOR /f "skip=2 tokens=2,*" %%A in ('reg.exe query "HKLM\SOFTWARE\Microsoft\MSBuild\ToolsVersions\4.0" /v MSBuildToolsPath') do @SET MSBUILDDIR=%%B
) ELSE (
@FOR /f "skip=2 tokens=2,*" %%A in ('reg.exe query "HKLM\SOFTWARE\Microsoft\MSBuild\ToolsVersions\14.0" /v MSBuildToolsPath') do @SET MSBUILDDIR=%%B
)

@ECHO Restoring Nuget Package for Solution ...
%SOLUPATH%\.nuget\NuGet.exe restore %SOLU%
@ECHO Restoring Nuget Package ends...

@IF "%SONAR%"=="true" (
@ECHO Begin Sonarqube static code analysis ...
%SONARRUNNER% begin /k:%KEY% /n:%VALUE% /v:%VERSION%
@ECHO.
)

@SET MSBUILDARGS=/t:Rebuild /v:m /m:2 /p:Configuration=Release 

@ECHO Rebuild in Release Mode...
@SET StartTime=%Time%
@"%MSBUILDDIR%\msbuild.exe" %SOLU% %MSBUILDARGS% /clp:ErrorsOnly /fl /flp:ErrorsOnly;WarningsOnly
@SET EndTime=%Time%
@SET BUILD_STATUS=%ERRORLEVEL% 
@IF not %BUILD_STATUS%==0 goto fail 
@ECHO Build Start: %StartTime%
@ECHO Build End:   %EndTime%
@ECHO.


REM @IF "%UTC%"=="true" (
REM @ECHO Starting UnitTest Execution.
REM @"%SCRIPTDIRECTORY%\xunit.runner.console.2.2.0\tools\xunit.console.exe" %SOLUPATH%\DH.CollateralGuard.Bll.New.Test\bin\Release\DH.CollateralGuard.Bll.New.Test.dll -xml "%CD%\XUnitResults.xml"
REM @"%SCRIPTDIRECTORY%\OpenCover.4.6.519\tools\OpenCover.Console.exe" -target:"%SCRIPTDIRECTORY%\xunit.runner.console.2.2.0\tools\xunit.console.exe" -targetargs:"%SOLUPATH%\DH.CollateralGuard.Bll.New.Test\bin\Release\DH.CollateralGuard.Bll.New.Test.dll" -output:"%CD%\OpenCoverResults.xml" -register:user -searchdirs:"%SOLUPATH%\DH.CollateralGuard.Bll.New.Test\bin\Release"
REM @SET BUILD_STATUS=%ERRORLEVEL% 
REM @IF not %BUILD_STATUS%==0 goto fail 
REM @ECHO.
REM )

@IF "%SONAR%"=="true" (
@ECHO End Sonarqube static code analysis ...
%SONARRUNNER% end
@ECHO.
)

@IF NOT "%CHAINEDCALL%"=="true" PAUSE
@ENDLOCAL
@GOTO End

:fail 
@EXIT /b 1 

:End