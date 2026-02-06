[cmdletBinding()]
param(
    [Parameter(Mandatory=$true,HelpMessage="BizTalk360 EnvironmentId. See Settings -> API Documentation.")]
    [string]$BizTalk360EnvironmentId,

    [Parameter(Mandatory=$true,HelpMessage="Url of the server where BizTalk360 is installed, e.g. http://localhost.")]
    [string]$BizTalk360ServerUrl,

    [Parameter(Mandatory=$false,HelpMessage="This is the identifier from the SetAlertMaintenance task.")]
    [string]$MaintenanceId = ""
)

$MaintenanceLabel = "DevOps deployment of {0}, {1}, attempt {2}" -f $Env:BUILD_DEFINITIONNAME,$Env:BUILD_BUILDNUMBER,$Env:SYSTEM_JOBATTEMPT

$ResponseSet = Invoke-RestMethod -Uri "$BizTalk360ServerUrl/BizTalk360/Services.REST/AdminService.svc/GetBizTalk360Info" -Method Get -UseDefaultCredentials
$ResponseSet | out-string
$BizTalk360Version = $ResponseSet.bizTalk360Info.biztalk360Version

## Between BizTalk360 9.0 and 9.1 a breaking change was done in the API
if ([Version]$BizTalk360Version -ge [Version]'9.1')
{
    $StopOperation = 'StopAlertMaintenance'
}
else
{
    $StopOperation = 'RemoveAlertMaintenance'
}

If ($MaintenanceId -eq "")
{
       Write-Host "MaintenanceId not specified. Trying to fetch latest from BizTalk360"
       $ResponseSet = Invoke-RestMethod -Uri "$BizTalk360ServerUrl/biztalk360/Services.REST/AlertService.svc/GetAlertMaintenance?environmentId=$BizTalk360EnvironmentId" -Method Get -UseDefaultCredentials
	   $ResponseSet | out-string

       $maintenance = @($ResponseSet.alertMaintenances | where { $_.comment -eq "$MaintenanceLabel" })

       If ($maintenance.Count -gt 0)
       {
             $MaintenanceId = $maintenance[$maintenance.Count - 1].maintenanceId 
       }
}

## Between BizTalk360 11.6 and 11.7 a breaking change was done in the API
if ([Version]$BizTalk360Version -ge [Version]'11.7')
{
    $Request = '{
    "environmentMaintenances": [
        {
            "maintenanceId": "' + $MaintenanceId + '",
            "environmentIds": [
                "' + $BizTalk360EnvironmentId + '"
            ]
        }
    ],
    "context": {
        "callerReference": "' + $MaintenanceLabel + '",
        "environmentSettings": {
            "id": "' + $BizTalk360EnvironmentId + '"
        }
    },
    "comment": "' + $MaintenanceLabel + '"
}'
}
else
{
    $Request = '{
      "context": {
          "callerReference": "' + $MaintenanceLabel + '",
          "environmentSettings": {
            "id": "' + $BizTalk360EnvironmentId + '"
          }
      },
      "maintenanceId": "' + $MaintenanceId + '",
      "comment": "' + $MaintenanceLabel + '"
    }'
}
Write-Host $Request

$ResponseSet = Invoke-RestMethod -Uri "$BizTalk360ServerUrl/biztalk360/Services.REST/AlertService.svc/$StopOperation" -Method Post -ContentType "application/json" -Body $Request -UseDefaultCredentials

If ($ResponseSet.success)
{
       Write-Host "BizTalk360 maintenance mode successfully disabled."
} 
