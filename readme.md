# GUCS Overview

The Grand Unified Check Summary (GUCS) is a unified single-file html reporting solution for PowerShell. The intent is to allow a single entry point to run multiple checks resulting in a single HTML file that can be viewed without additional files or plugins. This is achieved by embedding all images, and style sheets within the HTML file itself.

GUCS can add information to the report in 3 ways. You can add PowerShell directly into the template, reference a specific script by name, or, utilize GUCS automatic script execution by using the **{{$ExecutiveSummary}}** or **{{$TechnicalSummary}}** tags.

Additionaly, the structure of the report can be adjusted using the **reporttemplate.html** file and the visual style can be changed in the **style.css** file. Further style options are available for each subscript.

## How it works

GUCS will load the **reporttemplate.html** file and the **style.css** file. It will then search for any additional .css files in the **Subchecks** folder. These additional files are appended to the loaded **style.css** rules. The final product is then embedded in the loaded **reporttemplate.html** at the specified **{{$StyleContent}}** tag location. The script will then look for further tags and fill them in based on the tag type. All template tags begin and end in double curly braces "{{}}". Once all tags are embedded into the loaded template, the final result is saved as **Report.html** by default, then added to an e-mail and sent to the target recipients.

## Tags

The scripts, css, and images are embedded into your report at specific tag points. This section covers the use of the tags.

### {{$StyleContent}}

The CSS data located in the **style.css** file and all child .css files located in the **Subchecks** folder will be  agregated and stored wherever this tag is located. This should be placed within a **\<style\>** element.

### {{$ExecutiveSummary}}

All .ps1 files are grabbed from the root of the **Subchecks** folder and ran sequentially with the results being cached. Scripts not located at the root of the folder are ignored. Once all scripts are run, the **Summary** are cleaned up and converted into HTML, then embedded at this tags location. CSS classes are added to the output HTML to make styling with CSS easier.

### {{$TechnicalSummary}}

All .ps1 files are grabbed from the root of the **Subchecks** folder and ran sequentially with the results being cached. Scripts not located at the root of the folder are ignored. Once all scripts are run, the **TechnicalSummary** are cleaned up and converted into HTML, then embedded at this tags location. CSS classes are added to the output HTML to make styling with CSS easier.

### {{$SuccessStatus}}

This tag be replaced with either "Success" or "Failure" based on the status of **all** subchecks. If any report failed, then this will be "Failure". This can be used to set classes on HTML elements. For example, you could have two images, one with classes ```<div class="Status-Success Is{{$SuccessStatus}}"></div>``` and one with classes ```<div class="Status-Failure Is{{$SuccessStatus}}"></div>```. Then in your CSS you can style the Status-\* elements to be display: none by default and override that if the statuses match. Such as below, the end result of this, is the image that shows would match the total status of your checks.

```css
.Status-Success, .Status-Failure {
    display: none;
}
.Status-Success.IsSuccess, .Status-Failure.IsFailure {
    display: block;
}
```

### {{*SomeImage.png*}}

This tag will be replaced by a \<img\> element that contains a base64 source of the specified image from the **Subchecks** folder, so that it will not need to be included as a seperate file. Note that the image will be converted to png before being embedded.

Supported formats:

- .jpg
- .bmp
- .gif
- .png

### {{*SomeScriptName.ps1*}}

A tag that just contains the name of a script located in the Subchecks directory, will be replaced by the ExecutiveSummary output of that script. You can override this by adding a subvariable option. There are 3 available.

#### {{*SomeScriptName.ps1:Summary*}}

If the **Summary** subvariable is specified, the entire script tag will be replaced with the executive summary output of the script.

#### {{*SomeScriptName.ps1*:TechSummary}}

If the **TechSummary** subvariable is specified, the entire script tag will be replaced with the technical summary output of the script.

#### {{*SomeScriptName.ps1*:IsSuccess}}

If the **IsSuccess** subvariable is specified, the entire script tag will be replaced with the IsSuccess output of the script. This will either be "True" or "False". Similiar to the **{{$SuccessStatus}}** tag, this can be used to dynamically adjust css classes based on whether the script represents a failed check, or not. Example classes are below.

```css
.Status-Success, .Status-Failure {
    display: none;
}
.Status-Success.IsTrue, .Status-Failure.IsFalse {
    display: block;
}
```

For example, if you wanted to hide output on failure, your HTML element, in template, would look like below.

```html
<div class="Status-Success Is{{SomeScriptName.ps1:IsSuccess}}">{{SomeScriptName.ps1}}</div>
```

### {{$Some powershell code$}}

A tag beginning with **{{$** and ending with **$}}** will have the contents executed as powershell. For example, you could quickly embed the name of the machine running the script checks with the following.

```powershell
{{$return $env:COMPUTERNAME$}}
```

### Tag Processing Order

Tags are processed in a specific order.

1. {{$StyleContent}}
2. {{$ExecutiveSummary}} & {{$TechnicalSummary}}
3. {{$*PowerShell Code*$}}
4. {{*PowershellFile.ps1*[:SubVariable]}} & {{*ImageFile.*[jpg|bmp|png|gif]}}
5. {{$SuccessStatus}}

This leads to a potentialy useful pattern. Any tag at a lower processing level could output a tag to be processed at a higher level. For example, you could have **{{$SuccessStatus}}** somewhere in your CSS file, and it would be processed into "Success" or "Failure" before the report is sent because **{{$StyleContent}}** is processed before **{{$SuccessStatus}}**. The most useful option here though, would be to dynamically change embeded images by adding an image tag before the **{{*SomeImage.png*}}** step.

## Styling Guide

The **style.css** should be your first stop in customizing the report. This is your master styling template and is the first set of CSS rules applied. Each report author may optionally override a rule, but generally they should ensure their rules will only apply to their section of the report using selectors. GUCS automatically appends the reports returned **name** parameter as a class of that reports section to make this easier when using the **{{$TechnicalSummary}}** and **{{$ExecutiveSummary}}** tags.

Since css files in the **Subchecks** directory are appended to the master css file, the rules they contain will override the rules in **style.css**. The styling sheets may be located anywhere beneath the **Subchecks** folder.

You may edit the **reporttemplate.html** file to change the structure. If you use the **{{$StyleContent}}** tag, ensure that it is within a **\<style\>** element. If you ever need to add an image, ensure it is converted to base64 and embedded in the HTML or added through **{{*SomeImage.png*}}** tag to prevent dependency files. The **ReportingSupport.psm1** file contains a **Convert-ImageToHTML** command that will assist in manually embedding an image. Note that styling options should be kept in the css files and seperate from the structure options in the HTML.

## Subchecks Guide

Any child reports must be added to the **Subchecks** folder. The only requirement that GUCS needs of the child reports is that they return a valid PSObject with specific parameters. The **New-CheckStatus** function assists in this by providing a pre-initialized PSObject with all the expected properties. These child scripts must be placed at the root of the **Subchecks** folder if using the **{{$TechnicalSummary}}** and **{{$ExecutiveSummary}}** tags. This allows each subreport to have itself, child reports. It is perfectly legal to create a new folder under the **Subchecks** folder that contains scripts that report will run before returing the output to GUCS. If using a **{{*SomeScriptName.ps1*}}** tag, the relative path to the script may be used. For example, under **Subchecks** you could have another folder called **metrics** with a script called **cpu.ps1**. A valid script tag for this would be **{{metrics\cpu.ps1}}**

### Output format

The output object for a subcheck can be created with the **New-CheckStatus** function. This function is located in the **ReportingSupport.psm1** module which is automatically imported before the child functions are ran.

```powershell
New-CheckStatus -Name "My E-Mail Check" -Summary "My <b>Executive</b> Summary" -IsSuccess $true -TechnicalSummary @("asdf", "asdf") -IsTechnicalHTML $false -IsSummaryHTML $true -Priority 1000
```

#### Name

The name of your report/check. This is used to add a header to your section of the final report. Futher all non-word characters will be converted to underscores and the result of this is added as a class of the div for your report section. If you have multiple checks under the same name, they will be added to the same section in the final report. If you have 5 checks that all have the name "Overview", the will all be added under the same header.

#### IsSuccess

This boolean is a quick, yes/no answer to, did we pass this check? This is also used to add a class to divs generated for your section of the final report.

#### Priority

You can manually set the order in which the summaries are presented in the report by adjusting the priority in your output. Lower value = higher priority. So a check with priority 0 will show before a check with priority 1000. If you do not specify a priority, then it will default to 1000. Same-valued priorities are shown arbitrarily. If you have multiple checks with the same name, the priorities of all the checks are averaged, then compared. If you have two checks both named "Overview", one valued at 100, and the other at 0, the final priority will be 50 for the entire section. The priority is then compared between each of the subchecks, so that you can re-order subchecks within the section.

#### The Summaries

You have two summaries, the **Summary** and the **TechnicalSummary**. The **Summary** is your executive summary and should be kept brief where **TechnicalSummary** should contain details on the check. The summaries can be any type of object, but the object type will change the final HTML that is shown.

- $null: The entire section will not be added to the report. This is good if you want to only add general information, but don't need technical.
- String: Will become a single Paragraph element
- String with IsSummaryHTML or IsTechnicalHTML set to true: The string will be treated as raw HTML and added directly to the HTML template. This can be used to add images. If you do, you should load the image into memory, then convert it into an embeddable HTML using **Convert-ImageToHTML**. This will ensure you do not need to link the image or have the image with the HTML file.
- Object: Will be converted to string with it's default "ToString()" function, then treated the same as if it were a string to begin with.
- String[]: Will become an unordered list with each item in the array being a list item
- Object[]: Will become a table, whith each NoteProperty being added as a column, and the values being cells
- Hashtable: Will become a table, however you have two potential options. If you have a key called "Headings", then your table will be formated with the keys being ignored, and the entries in heading being add as column headers, and the rest of the key'd values being added as rows. Example

```powershell
@{"Headings"=@("Name","Color");"Row1"=@("John","Blue");"asdf"=@("Jake","Red")}
```

Will return a table with headers "Name" and "Color", with two rows, one with "John" and "Blue" under their respective headers and one with "Jake" and "Red" under their respective headers.
Your other option is a hashtable without the "Headings" key. In this case, each key will be a header, and the values will become cells. Example

```powershell
@{"Name"=@("John","Jack");"Favorite Color"=@("Red","Green"); "Age"=@("23","42")}
```

Will create a table with headings "Name", "Favorite Color" and "Age". With 2 rows being, "John","Red","23" and "Jack","Green","42"

Both **Summary** and **TechnicalSummary** follow these rules. You may have a table in the executive summary if you wish. Note that all of these outputs will be placed within their own \<div\> element with css classes added based on your report name and whether it passed the check or not. (StatusSuccess, or StatusFailure)

### Exception for {{$*Some powershell code*$}} tag

The output of a script block in the format of **{{$*Some powershell code*$}}** does not need to be of the **New-CheckStatus**. If it is, then the normal rules apply for the processing of the output. If the output of this tag is not in the **New-CheckStatus** format and is instead a string, the string is added to the template directly as if your had selected the **IsHTML** option of the **New-CheckStatus** function. If the output is any other object, then the script will treat the output as if it was the summary of a **New-CheckStatus** and will follow the rules outlined in the **The Summaries** section.

## Installation

- Copy the files to your install directory
- Remove the example checks from the **Subchecks** folder. And replace them with checks of your own.
- Edit the **RunChecks.ps1** and ensure the parameters are set at the top of the script. This way you can use a scheduled task without having to provide parameters.
- Create a service account that has the minimum amount of required access to perform your checks.
- Test the report to ensure all subreports are working correctly.
- Create a scheduled task with an application of "PowerShell.exe" and arguments of "&'\<path to script\>'"

## Further Examples

Pre-built reports can be located in the included Examples folder.