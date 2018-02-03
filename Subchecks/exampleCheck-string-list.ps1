#Do checks
#Create return object
$ToReturn = New-CheckStatus -Name "Example by array strings (list)" -IsSuccess $true -TechnicalSummary @("John.Doe: Good", "John.Doe: Good") -Summary @("all", "good") -IsTechnicalHTML $false -IsSummaryHTML $false
return $ToReturn