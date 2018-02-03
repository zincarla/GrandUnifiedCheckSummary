#Do checks
$err = "";
try {
    $result = Test-Connection "google.com" -ea stop
} catch {
    $err=$_.ToString();
}
$IsGood = $false;
$Summary = "We did not reach google"
if ($result) {
    $IsGood = $true
    $Summary = "We reached google"
    $filteredResults = @()
    foreach ($tresult in $result) {
        $filteredResults += Convert-ToPSObject -OriginalObject $tresult -Properties @("IPV4Address", "ResponseTime")
    }
    $result = $filteredResults
} else {
    $result = $err;
}


#Create return object
$ToReturn = New-CheckStatus -Name "Example by array objects google filtered" -IsSuccess $IsGood -TechnicalSummary $result -Summary $Summary -IsTechnicalHTML $false -IsSummaryHTML $false
return $ToReturn