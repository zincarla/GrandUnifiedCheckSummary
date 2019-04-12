#Update this with https://support.microsoft.com/en-us/help/13853/windows-lifecycle-fact-sheet
$WindowsVersions = @(
    (New-Object -TypeName PSObject -Property @{Name="Windows 10 1511";EndDate =[DateTime]"2017-10-10";StartDate=[DateTime]"2015-11-10"}),
    (New-Object -TypeName PSObject -Property @{Name="Windows 10 1607";EndDate =[DateTime]"2019-04-09";StartDate=[DateTime]"2016-08-02"}),
    (New-Object -TypeName PSObject -Property @{Name="Windows 10 1703";EndDate =[DateTime]"2019-10-08";StartDate=[DateTime]"2017-04-05"}),
    (New-Object -TypeName PSObject -Property @{Name="Windows 10 1709";EndDate =[DateTime]"2020-04-14";StartDate=[DateTime]"2017-10-17"}),
    (New-Object -TypeName PSObject -Property @{Name="Windows 10 1803";EndDate =[DateTime]"2020-11-10";StartDate=[DateTime]"2018-04-30"}),
    (New-Object -TypeName PSObject -Property @{Name="Windows 10 1809";EndDate =[DateTime]"2021-05-11";StartDate=[DateTime]"2018-11-13"})
)

$Total = ""

foreach ($Version in $WindowsVersions) {
    if ($Version.EndDate -gt [DateTime]::Now.AddMonths(-2)) {
        $SupportSpan = ($Version.EndDate - $Version.StartDate).TotalDays
        $Percent = 100-(($SupportSpan-(($Version.EndDate-[DateTime]::Now).TotalDays))*100 /$SupportSpan)
        if ($Percent -lt 0) {$Percent = 0}
        if ($Percent -gt 100) {$Percent = 100}

        $DayTag = [Math]::Floor(($Version.EndDate-[DateTime]::Now).TotalDays).ToString()+" days remaining"

        if (($Version.EndDate-[DateTime]::Now).TotalDays -lt 0) {
            $DayTag = [Math]::Floor(($Version.EndDate-[DateTime]::Now).TotalDays).ToString()+" days expired"
        }

        $Total += New-HTMLBar -Size $Percent -Text ($Version.Name+" ("+$DayTag+")")
    }
    #Won't list if expired by more than 2 months
}

$ToReturn = New-CheckStatus -Name "Windows10Expires" -IsSuccess $true -TechnicalSummary $Total -Summary $Total -IsTechnicalHTML $true -IsSummaryHTML $true
return $ToReturn