$Software = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$Software += Get-ChildItem -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
$Results = @()
foreach ($Item in $Software) {
    $Props = Get-ItemProperty -Path $Item.PSPath
    if ($Props.DisplayName-ne $null -and $Props.DisplayName -ne "" -and $Props.DisplayName -notlike "Update for *" -and $Props.DisplayName -notlike "Security Update for *" -and $Props.DisplayName -notlike "Definition Update *") {
        $Results += New-Object -TypeName PSObject -Property @{Name=$Props.DisplayName;Publisher=$Props.Publisher;Version=$Props.DisplayVersion}
    }
}

#Create return object
$ToReturn = New-CheckStatus -Name "Installed Software" -IsSuccess $true -TechnicalSummary $Results -Summary $null -IsTechnicalHTML $false -IsSummaryHTML $false
return $ToReturn