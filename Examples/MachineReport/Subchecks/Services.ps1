$Services = Get-Service
$Results = @()
$Props = @("DisplayName", "Name","Status")
foreach ($Item in $Services) {
    $Results += Convert-ToPSObject -OriginalObject $Item -Properties $Props
}

#Create return object
$ToReturn = New-CheckStatus -Name "Services" -IsSuccess $true -TechnicalSummary $Results -Summary $null -IsTechnicalHTML $false -IsSummaryHTML $false
return $ToReturn