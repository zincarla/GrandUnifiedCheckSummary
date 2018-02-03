#Do checks
#Create return object
$ToReturn = New-CheckStatus -Name "Network Metrics" -IsSuccess $true -TechnicalSummary $null -Summary "<h3>Users: </h3> 540" -IsTechnicalHTML $false -IsSummaryHTML $true -Priority 0
return $ToReturn