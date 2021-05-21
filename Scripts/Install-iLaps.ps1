#Requires -Version 3.0
<#

    .SYNOPSIS
    Download executable from Azure Storage BLOB, and execute it.

    .DESCRIPTION
    This downloads and executes an execuatable from Azure Storage BLOB.

    .PARAMETER

    .EXAMPLE

    .NOTES
    Original Author: Alex Ã˜. T. Hansen
    Current Implementation Author: Dhruv Bhavsar
    Date: 19-05-2020
    Last Updated: 19-05-2020

#>

[CmdletBinding()]
    
Param
(
    #Run Script In Debugger Mode
    [parameter(Mandatory = $false)][bool]$DebugMode = $false
)
################################################
<# Bootstrap - Start #>

#Create log folder.
New-Item -ItemType Directory -Force -Path "C:\Logs\Intune LAPS" | Out-Null;

<# Bootstrap - End #>
################################################
<# Input - Start #>

#Azure.
$AzureEndpoint = 'https://Storage-Account-Name.file.Storage-Account-Suffix';
$AzureSharedAccessSignature = 'File-Object-Read-Installer-SAS-Token';
$AzureFileShare = "Installer-Container-Name";

#Log.
$LogFile = ("C:\Logs\Intune LAPS\" + ((Get-Date).ToString("ddMMyyyy") + ".log"));

<# Input - End #>
################################################
<# Functions - Start #>

Function Write-Log {
    [CmdletBinding()]
    
    Param
    (
        [parameter(Mandatory = $true)][string]$File,
        [parameter(Mandatory = $true)][string]$Text,
        [parameter(Mandatory = $true)][string][ValidateSet("Information", "Error", "Warning")]$Status
    )

    #Construct output.
    $Output = ("[" + (((Get-Date).ToShortDateString()) + "][" + (Get-Date).ToLongTimeString()) + "][" + $Status + "] " + $Text);
    
    #Output.
    $Output | Out-File -Encoding UTF8 -Force -FilePath $File -Append;
    Return Write-Output $Output;
}

<# Functions - End #>
################################################
<# Main - Start #>

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text "Starting download request.";

#Get temporary location.
$Path = "C:\Windows\system32";
If ($DebugMode) {
    $Path = "C:\dev";
}

#Installation package.
$Installer = "Reset-LocalAdministratorPassword.ps1";

#Request application from BLOB storage.
Remove-Item ($Path + "\" + $Installer) -ErrorAction Ignore;
Invoke-WebRequest ($AzureEndpoint + "/" + $AzureFileShare + "/" + $Installer + $AzureSharedAccessSignature) -OutFile ($Path + "\" + $Installer);

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text "Finished download request for $($Installer)";
Write-Log -File $LogFile -Status Information -Text "Running executable.";

#Execute the application.
Start-Process powershell.exe -ArgumentList "-file $($Path)\$($Installer)"


$Installer = "Check-Reset-LocalAdministratorPassword.ps1";
Remove-Item ($Path + "\" + $Installer) -ErrorAction Ignore;
Invoke-WebRequest ($AzureEndpoint + "/" + $AzureFileShare + "/" + $Installer + $AzureSharedAccessSignature) -OutFile ($Path + "\" + $Installer);

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text "Finished download request for $($Installer)";
Write-Log -File $LogFile -Status Information -Text "Running executable.";

#Execute the application.
Start-Process powershell.exe -ArgumentList "-file $($Path)\$($Installer)"
<# Main - End #>
################################################