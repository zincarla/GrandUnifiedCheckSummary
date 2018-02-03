#Do checks
$Percentage = (Get-WmiObject win32_processor).LoadPercentage
$Success = $true;
if ($Percentage -gt 75) {
    $Success = $false;
}
#Create return object
$ToReturn = New-CheckStatus -Name "Network Metrics" -IsSuccess $Success -TechnicalSummary $Percentage -Summary "<h3>CPU Utilization: </h3> $Percentage%" -IsTechnicalHTML $false -IsSummaryHTML $true -Priority 0
return $ToReturn