Param
(
    $EmailTargets=@(),
    $EmailFrom,
    $SMTPServer,
    $EmailSubjectPrefix ="Checks are",
    $ReportTemplate = ".\reporttemplate.html",
    $StyleSheetTemplate = ".\style.css",
    $SaveLocation = ".\Report.html",
    $EBody = "Please see the attached report for full detail. Below is a summary.`r`n"
)

#region Initialize variables and environment
#Change Working Directory so relative paths work
Push-Location -Path ($PSScriptRoot)

#Import module
#Check if module imported, if not import
if ((Get-Module|Where-Object -FilterScript {$_.Name -eq "StigSupport"}).Count -le 0)
{
    Import-Module ".\ReportingSupport.psm1" -ErrorAction Stop
}
#Add other assemblies as needed
Add-Type -AssemblyName "System.Web" -ErrorAction Stop
Add-Type -AssemblyName "System.Drawing" -ErrorAction Stop

#Consolidate targets as required by e-mail function
$EmailTo = ""
$EmailTargets | ForEach-Object {$EmailTo+=$_+","}
$EmailTo = $EmailTo.TrimEnd(',')
if ([string]::IsNullOrEmpty($EmailTo.Length) -or [string]::IsNullOrEmpty($EmailFrom) -or [string]::IsNullOrEmpty($SMTPServer)) {
    Write-Warning "A report is useless if no one looks at it. Email targets missing, EmailFrom not set, or SMTPServer is not set. The report will still be generated, but not e-mailed."
}
#Load in template
$HTMLReport= Get-Content -Path $ReportTemplate -Raw

#Start counters
#Failed Check counter will result in a final success/failure
$FailedChecks =0
$TotalChecks =0

#These will hold the summary category results if used
$ExecutiveSummary = ""
$TechnicalSummary = ""
#endregion

#region Add CSS Templates
#Grab template
$StyleContent = ""
if ($StyleSheetTemplate -ne $null) {
    $StyleContent += "/*Style from: $StyleSheetTemplate*/" +(Get-Content -Path $StyleSheetTemplate -Raw)
}
#Add additional child CSS templates
$ChildCSS = @()+(Get-ChildItem -Path ".\Subchecks" -Recurse -Filter "*.css")
foreach ($File in $ChildCSS) {
    $StyleContent = $StyleContent + "/*Style from: $($File.Name)*/" + (Get-Content -Path $File.FullName -Raw)
}
#Embed CSS in HTML
$HTMLReport = $HTMLReport.Replace("{{`$StyleContent}}", $StyleContent)
#endregion

#region Broad Auto Summaries
#Now we will search for the two broad summary tags
#These tags mean we will have to run -all- the scripts and dynamically add them to the report.
if ($HTMLReport.Contains("{{`$ExecutiveSummary}}") -or $HTMLReport.Contains("{{`$TechnicalSummary}}")) {
    #Run all reports then
    #Grab an array of all sub reports to be run
    $SubReports = @()+ (Get-ChildItem -Path ".\Subchecks" -Filter "*.ps1")

    #Loop through and run all reports, caching results in $Results
    $Results = @()
    foreach ($Report in $SubReports) {
        $NewReport = &"$($Report.FullName)";
        $NewReport | Add-Member -MemberType NoteProperty -Name "OriginatingScript" -Value $Report.Name
        $Results+= $NewReport
    }

    #Loop through the results and build a summary table, this is used to sort and filter the results
    $Results = $Results | Sort-Object -Property Name
    $ResultTable = @{}
    foreach ($Result in $Results) {
        if ($ResultTable.ContainsKey($Result.Name)) {
            $ResultTable[$Result.Name] += $Result
        } else {
            $ResultTable += @{$Result.Name=@($Result)}
        }
    }
    #Filter scripts again by priority, store the priority order in an array
    $ResultsByPriority = @()
    foreach ($ResultName in $ResultTable.Keys) {
        $TotalPriority = 0;
        $ResultArray = $ResultTable[$ResultName]
        foreach ($Result in $ResultArray) {
            $TotalPriority += $Result.Priority
        }
        $ResultsByPriority += New-Object -TypeName PSObject -Property @{Name=$ResultName;AvgPriority=($TotalPriority/$ResultArray.Count)}
    }
    $ResultsByPriority =@()+($ResultsByPriority | Sort-Object -Property AvgPriority).Name
    #Finally loop through each of the individual sections, and build the two summaries sorted by priority
    for ($ResultIndex =0; $ResultIndex -lt $ResultsByPriority.Count;$ResultIndex++) {
        $ResultName = $ResultsByPriority[$ResultIndex]
        #Sort the sub checks for each subsection by priority
        $ResultArray = @();
        if ($ResultTable[$ResultName].Count -gt 1) {
            $ResultArray += (@()+$ResultTable[$ResultName]) | Sort-Object -Property Priority
        } else {
            #Unless we only have one object, then just return the array
            $ResultArray += $ResultTable[$ResultName]
        }
        #Increment our total check count
        $TotalChecks++;
        #Initialize our variables
        $TotalStatusFailed = $false;
        $AnyExecutiveOutput = $false;
        $AnyTechnicalOutput = $false;
        $SubExecSummary = "";
        $SubTechSummary = "";
        #Process the results, in order, to HTML
        for ($SubResultIndex =0; $SubResultIndex -lt $ResultArray.Count;$SubResultIndex++) {
            $Result = $ResultArray[$SubResultIndex]
            Write-Host "- $($Result.Name)"
            #Mark entire section as failed due to this failure if needed
            if (-not $Result.IsSuccess) {
                $TotalStatusFailed=$true;
            }
            #Convert the two summaries to HTML
            $ConvertedSummary = Convert-SummaryToHTML -Summary $Result.Summary -IsSuccess $Result.IsSuccess -Name $Result.Name -IsHTML $Result.IsSummaryHTML
            if ($ConvertedSummary) {
                $AnyExecutiveOutput=$true
                #Add comment on originating script for troubleshooting
                $SubExecSummary += "<!-- This element from $($Result.OriginatingScript) -->"
                $SubExecSummary += $ConvertedSummary + "`r`n"
            }
            $ConvertedSummary = Convert-SummaryToHTML -Summary $Result.TechnicalSummary -IsSuccess $Result.IsSuccess -Name $Result.Name -IsHTML $Result.IsTechnicalHTML
            if ($ConvertedSummary) {
                $AnyTechnicalOutput += $true
                #Add comment on originating script for troubleshooting
                $SubTechSummary += "<!-- This element from $($Result.OriginatingScript) -->"
                $SubTechSummary += $ConvertedSummary+"`r`n"
            }
        }
        #Add our section rapper with classes denoting the check, and the status of the check
        $Class="StatusSuccess"
        if ($TotalStatusFailed) {
            $FailedChecks++;
            $Class = "StatusFailure"
        }
        $AdditionalClasses = "$Class $($ResultName -Replace "\W","_")"
        if ($AnyExecutiveOutput) {
            $ExecutiveSummary += "<h2 class=`"$AdditionalClasses`">$($ResultName)</h2>`r`n" + "<div class=`"ResultGrouping $AdditionalClasses`">`r`n" + $SubExecSummary  + "</div>`r`n"
        }
        if ($AnyTechnicalOutput) {
            $TechnicalSummary += "<h2 class=`"$AdditionalClasses`">$($ResultName)</h2>`r`n"+"<div class=`"ResultGrouping $AdditionalClasses`">`r`n" + $SubTechSummary + "</div>`r`n"
        }
        $Class = $Class.Replace("Status","")
        #Add broad success to email body
        $EBody += "$ResultName ($Class)`r`n"
    }
    #Now replace the necessary tags for the summaries
    #Add to HTML Template
    $HTMLReport = $HTMLReport.Replace("{{`$ExecutiveSummary}}", $ExecutiveSummary)
    $HTMLReport = $HTMLReport.Replace("{{`$TechnicalSummary}}", $TechnicalSummary)
}
#endregion

#region InlinePowerShell
#Use REGEX to pull inline powershell tags
$Regex = [regex]::new("\{\{`\$.*?`\$\}\}")
$ScriptTags = $Regex.Matches($HTMLReport).Value | Sort-Object | Select -Unique
$Processed = @()
#Run the scripts
$Results = @()
foreach ($Script in $ScriptTags) {
    #Trim off the {{$ and $}}
    $ScriptBlock = $Script.SubString(3, $Script.Length -6)
    #If we have not already run this script
    if (-not $Processed.Contains($ScriptBlock)) {
        $Processed += $ScriptBlock
        $NewReport = ""
        $NewReport = Invoke-Expression -Command $ScriptBlock
        $Members = ($NewReport | Get-Member).Name
        if ($Members.Contains("IsSuccess") -and 
            $Members.Contains("TechnicalSummary") -and 
            $Members.Contains("Summary") -and 
            $Members.Contains("Name") -and 
            $Members.Contains("IsTechnicalHTML") -and 
            $Members.Contains("IsSummaryHTML") -and 
            $Members.Contains("Priority"))
        {
            #We will only add check counter if returned object is a reporting object
            if (-not $NewReport.IsSuccess) {
                $FailedChecks++;
            }
            $TotalChecks++;
        } elseif ($NewReport.GetType().Name -eq "String") {
            $NewReport = New-CheckStatus -IsSuccess $true -TechnicalSummary $NewReport -Summary $NewReport -Name "InlinePowershell" -IsTechnicalHTML $true -IsSummaryHTML $true
        } 
        else {
            $NewReport = New-CheckStatus -IsSuccess $true -TechnicalSummary $NewReport -Summary $NewReport -Name "InlinePowershell" -IsTechnicalHTML $false -IsSummaryHTML $false
        }
        $NewReport | Add-Member -MemberType NoteProperty -Name "OriginatingScript" -Value $ScriptBlock
        $Results+= $NewReport
    }
}

foreach ($Result in $Results) {
    Write-Host $Result.Name
    $NewTechSummary = Convert-SummaryToHTML -Summary $Result.TechnicalSummary -IsSuccess $Result.IsSuccess -Name $Result.Name -IsHTML $Result.IsTechnicalHTML -NoSubresultDIV
    $HTMLReport = $HTMLReport.Replace("{{`$"+$Result.OriginatingScript+"`$}}", $NewTechSummary)
}
#endregion

#region InlineFiles
#Use REGEX to pull script and image tags
$Regex = [regex]::new("\{\{[a-zA-Z0-9 -_.:]+\}\}")
$ScriptTags = $Regex.Matches($HTMLReport).Value | Sort-Object | Select -Unique
$Processed = @()
#Run reports
$Results = @()
foreach ($Script in $ScriptTags) {
    #Trim off the {{ and }}
    $ScriptFileName = $Script.SubString(2, $Script.Length -4)
    #Trim off any variable requests <scriptname>:<variablerequest>
    if ($ScriptFileName.Contains(":")) {
        $ScriptFileName = $ScriptFileName.Split(":",[StringSplitOptions]::None)[0]
    }
    #If we have not already run this script
    if (-not $Processed.Contains($ScriptFileName)) {
        $Processed += $ScriptFileName
        $ScriptName = ".\Subchecks\"+$ScriptFileName
        #If it is a script, run it
        if ($ScriptName.EndsWith(".ps1")) {
            $NewReport = &"$($ScriptName)";
            $NewReport | Add-Member -MemberType NoteProperty -Name "OriginatingScript" -Value $ScriptFileName
            $Results+= $NewReport
            if (-not $NewReport.IsSuccess) {
                $FailedChecks++;
            }
            $TotalChecks++;
        } else {
            #If it is not a script, check if it is an image, and embed it
            if ($ScriptName.EndsWith(".jpg") -or $ScriptName.EndsWith(".bmp") -or $ScriptName.EndsWith(".jpeg") -or $ScriptName.EndsWith(".gif") -or $ScriptName.EndsWith(".png")) {
                $Image = Get-Item -Path (".\Subchecks\"+$Script.SubString(2, $Script.Length -4))
                $Content = Convert-ImageToHTML -Image ([System.Drawing.Bitmap]::FromFile($Image.FullName))
                #Replace tag with image now as there are not variable requests with images.
                $HTMLReport = $HTMLReport.Replace($Script, $Content)
            }
            if ($ScriptName.EndsWith(".svg")) {
                $Image = Get-Item -Path (".\Subchecks\"+$Script.SubString(2, $Script.Length -4))
                $Content = Import-SVG -PathToImage $Image.FullName
                #Replace tag with image now as there are not variable requests with images.
                $HTMLReport = $HTMLReport.Replace($Script, $Content)
            }
        }
    }
}

#at this point, we have a list of normal script tags, and we have run the necessary scripts to fill in these tags
#so fill them in
#Loop through the script results and add to template by replacing the necessary tags
foreach ($Result in $Results) {
    Write-Host $Result.Name
    $NewSummary = Convert-SummaryToHTML -Summary $Result.Summary -IsSuccess $Result.IsSuccess -Name $Result.Name -IsHTML $Result.IsSummaryHTML -NoSubresultDIV
    $NewTechSummary = Convert-SummaryToHTML -Summary $Result.TechnicalSummary -IsSuccess $Result.IsSuccess -Name $Result.Name -IsHTML $Result.IsTechnicalHTML -NoSubresultDIV
    $IsSuccess = $Result.IsSuccess.ToString()
    $HTMLReport = $HTMLReport.Replace("{{"+$Result.OriginatingScript+"}}", $NewSummary)
    $HTMLReport = $HTMLReport.Replace("{{"+$Result.OriginatingScript+":Summary}}", $NewSummary)
    $HTMLReport = $HTMLReport.Replace("{{"+$Result.OriginatingScript+":TechSummary}}", $NewTechSummary)
    $HTMLReport = $HTMLReport.Replace("{{"+$Result.OriginatingScript+":IsSuccess}}", $IsSuccess)
}

#Fill in e-mail body
$ResultNames = $Results.Name | Sort-Object | Select -Unique
foreach ($Name in $ResultNames) {
    $FailedResults = $Results | Where-Object {$_.Name -eq $Name -and $_.IsSuccess -eq $false}
    if ($FailedResults.Count -eq 0) {
        $EBody += "$Name (Success)`r`n"
    } else {
        $EBody += "$Name (Failed)`r`n"
    }
}
#endregion

#region Handle static variable tags
#Replace SuccessStatus Tag
$SuccessStatus = "Success"
if ($FailedChecks -ne 0) {
    $SuccessStatus = "Failure"
}
$HTMLReport = $HTMLReport.Replace("{{`$SuccessStatus}}", $SuccessStatus)
#endregion

#region End, Save Report and e-mail
#Write Report to disk
$HTMLReport | Out-File -FilePath $SaveLocation
$SaveLocation = (Get-Item -Path $SaveLocation).FullName #System.Net.Mail.Attachment does not appear to support relative paths. Unpack it.

#Set an e-mail summary saying how many are good
$Adjective = "Good"
if ($FailedChecks -ne 0) {
    $Adjective = "Bad"
}
$EMailSummary = "$EmailSubjectPrefix $Adjective ($FailedChecks/$TotalChecks Failed)"
if ($SMTPServer -ne $null -and $SMTPServer -ne "" -and $EmailFrom -ne "" -and $EmailFrom -ne $null -and $EmailTo -ne "" -and $EmailTo -ne $null) {
    $smtp= New-Object System.Net.Mail.SmtpClient $SMTPServer
    $msg = New-Object System.Net.Mail.MailMessage 
    $msg.To.Add($EMailTo)
    $msg.from = $EmailFrom
    $msg.subject = $EMailSummary
    $msg.body = $EBody
    $msg.isBodyhtml = $false
    $attachmentData = New-Object System.Net.Mail.Attachment -ArgumentList @($SaveLocation, [System.Net.Mime.MediaTypeNames+Text]::Html);
    $msg.Attachments.Add($attachmentData);
    $smtp.send($msg)
    $smtp.Dispose();
    $attachmentData.Dispose()
    $msg.Dispose();
}
Write-Host "------E-Mail Subject-------"
Write-Host $EMailSummary
Write-Host "--------EMail Body---------"
Write-Host $EBody
Pop-Location
#endregion
