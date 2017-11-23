<html>
<body>
Team Project: $env:SYSTEM_TEAMPROJECT\n	
Build Name: $defname \n
Build Number: $($build.buildnumber) \n
Source Branch : $($build.sourceBranch)\n
Source GetVersion: $($Build.SourceVersion)\n
<p>Build URL: $($build._links.web.href) \n</p>
<p>Build URL Plaintext: $($build.url)\n</p>
________________________________________________________________\n
Basic Details\n
________________________________________________________________\n
Build Agent: $env:AGENT_NAME \n
Build Configuration: $($build.parameters | ConvertFrom-Json | select -ExpandProperty BuildConfiguration)\n
Build Platform: $($build.parameters | ConvertFrom-Json | select -ExpandProperty BuildPlatform)\n
Build Reason: $($build.reason)\n
Requested By: $($build.requestedBy.displayName)\n
Requested For: $($build.requestedFor.displayName)\n
Build Queue Time: $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.queueTime)\n
Build Start Time: $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.startTime)\n
Last Change Date: $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.lastChangedDate)\n
Last Changed By: $($build.lastChangedBy.displayName)\n

\n\n
_____________________________________________________________\n
Associated change sets/commits:\n
_____________________________________________________________\n
@@CSLOOP@@  
ID: $($csdetail.changesetid)$($csdetail.commitid)\n
Comment: $($csdetail.comment)\n
Owner/Author: $($csdetail.author)\n
Committer: $($csdetail.committer)\n
<p>URL: $($csdetail._links.web.href)\n</p>
<p>URL Plaintext: $($csdetail.url)\n</p>
_____________________________________________________________\n
@@CSLOOP@@

</body>
</html>