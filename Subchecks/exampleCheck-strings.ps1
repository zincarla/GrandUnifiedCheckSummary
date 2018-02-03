#Do checks
#Create return object
$ToReturn = New-CheckStatus -Name "Example by string (string)" -IsSuccess $false -TechnicalSummary "We checked, it's bad!" -Summary "Bad" -IsTechnicalHTML $false -IsSummaryHTML $false
return $ToReturn