#Do checks
$OS = gwmi -Class win32_operatingsystem
$Percentage = [Math]::Round(((($OS.TotalVisibleMemorySize - $OS.FreePhysicalMemory)*100)/ $OS.TotalVisibleMemorySize))
$Success = $true;
if ($Percentage -gt 75) {
    $Success = $false;
}
#Create return object
$ToReturn = New-CheckStatus -Name "Network Metrics" -IsSuccess $Success -TechnicalSummary $null -Summary "<h3>Memory Utilization: </h3> $Percentage%" -IsTechnicalHTML $false -IsSummaryHTML $true -Priority 0
return $ToReturn