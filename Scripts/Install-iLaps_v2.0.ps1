#Requires -Version 3.0
<#

    .SYNOPSIS
    Download scripts from Azure Storage BLOB, and execute them.

    .DESCRIPTION
    This downloads and executes scripts from Azure Storage BLOB.

    .PARAMETER

    .EXAMPLE

    .NOTES
    Original Author: Alex Ã˜. T. Hansen
    Current Implementation Author: Dhruv Bhavsar and Theron Howton
    Date: 19-05-2020
    Last Updated: 04-16-2021

#>

[CmdletBinding()]
    
Param
(
    #Run Script In Debugger Mode
    [parameter(Mandatory = $false)][bool]$DebugMode = $false
)
################################################
<# Bootstrap - Start #>

# Variables
$LogFilePath = "C:\Logs\Intune Management"
$V1CleanupPath = "C:\Windows\System32"
$ScriptsFilePath = "C:\Windows\System32\Intune Management"
$Solution = "iLaps"
$LogFile = ("$LogFilePath\" + "$Solution-" + ((Get-Date).ToString("yyyyMMdd") + ".log"));

# Working Directories
$Path = "$ScriptsFilePath\$Solution";
If ($DebugMode) {
    $Path = "$ScriptsFilePath\$Solution\dev";
}

# Installation packages - script names
$V1Installers = @(
    "Reset-LocalAdministratorPassword.ps1",
    "Check-Reset-LocalAdministratorPassword.ps1"
) 

$Installers = @(
    "Reset-LocalAdministratorPassword_v2.0.ps1",
    "Check-Reset-LocalAdministratorPassword_v2.0.ps1"
) 

<# Bootstrap - End #>
################################################
<# Input - Start #>

# Azure connection info
$AzureEndpoint = 'https://Storage-Account-Name.blob.Storage-Account-Suffix';
$AzureSharedAccessSignature = 'Blob-Object-Read-Installer-SAS-Token';
$AzureFileShare = "Installer-Container-Name";


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

# Create Intune Management log folder
try {
    If (!(Test-Path $LogFilePath)) {
        New-Item -ItemType Directory -Path $LogFilePath -Force | Out-Null;
        Write-Log -File $LogFile -Status Information -Text "'$LogFilePath' logs folder created.";
    }
}
catch {
    Write-Log -File $LogFile -Status Error -Text "$Error[0]"
}

# ACL Intune Management log folder, grants only SYSTEM and local admins Full Control
try {
    If (Test-Path $LogFilePath) {
        icacls "$LogFilePath" /inheritance:r | Out-Null;
        $acl = Get-Acl $LogFilePath;
        $AccessRule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow");
        $accessRule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow");
        $acl.AddAccessRule($AccessRule1);
        $acl.AddAccessRule($AccessRule2);
        $acl | Set-Acl $LogFilePath;
        Write-Log -File $LogFile -Status Information -Text "'$LogFilePath' logs folder ACLed.";
    } 
}
catch {
    Write-Log -File $LogFile -Status Error -Text "$Error[0]"
}

# Clear variables to be used in next section
$acl = $null;
$AccessRule = $null;

# Create Intune Management scripts folder
try {
    If (!(Test-Path $ScriptsFilePath)) {
        New-Item -ItemType Directory -Path $ScriptsFilePath\$Solution -Force | Out-Null;
        Write-Log -File $LogFile -Status Information -Text "'$ScriptsFilePath\$Solution' scripts folder created.";
    }
}
catch {
    Write-Log -File $LogFile -Status Error -Text "$Error[0]"
}

# Create debugging folder, if needed.
try {
    if ($DebugMode) {
        New-Item -ItemType Directory -Path $ScriptsFilePath\$Solution\dev -Force | Out-Null;
        Write-Log -File $LogFile -Status Information -Text "'$ScriptsFilePath\$Solution\dev' scripts folder created.";
    }
}
catch {
    Write-Log -File $LogFile -Status Error -Text "$Error[0]"
}

# ACL Intune Management scripts folder, grants only SYSTEM Full Control
try {
    If (Test-Path $ScriptsFilePath) {
        icacls "$ScriptsFilePath" /inheritance:r | Out-Null
        $acl = Get-Acl $ScriptsFilePath;
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow");
        $acl.AddAccessRule($AccessRule);
        $acl | Set-Acl $ScriptsFilePath;
        Write-Log -File $LogFile -Status Information -Text "'$ScriptsFilePath\$Solution' scripts folder ACLed.";
    }
}
catch {
    Write-Log -File $LogFile -Status Error -Text "$Error[0]"
}

# Download scripts from BLOB storage.
Write-Log -File $LogFile -Status Information -Text "Starting V1 script cleanup";
foreach ($Installer in $V1Installers) {
    try {
        # Remove V1 Scripts if they exist
        Remove-Item ($V1CleanupPath + "\" + $Installer) -ErrorAction Ignore;
    }
    catch {
        Write-Log -File $LogFile -Status Error -Text "$Error[0]"
    }
}
Write-Log -File $LogFile -Status Information -Text "Starting download request.";

foreach ($Installer in $Installers) {
    try {
        # Remove existing scripts.
        Remove-Item ($Path + "\" + $Installer) -ErrorAction Ignore;
        # Download scripts from Azure BLOB storage
        Invoke-WebRequest ($AzureEndpoint + "/" + $AzureFileShare + "/" + $Installer + $AzureSharedAccessSignature) -OutFile ($Path + "\" + $Installer);
        Write-Log -File $LogFile -Status Information -Text "Finished download request for $($Installer).";
        Write-Log -File $LogFile -Status Information -Text "Running $($installer).";
       
        # Execute downloaded scripts
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy bypass -file `"$($path)`"\$Installer" -Wait -PassThru
        Write-Log -File $LogFile -Status Information -Text "$($installer) completed successfully."; 
    }
    catch {
        Write-Log -File $LogFile -Status Error -Text "$Error[0]"
    }
}
<# Main - End #>
################################################