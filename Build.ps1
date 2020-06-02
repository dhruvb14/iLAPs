#Requires -Version 3.0
<#

    .SYNOPSIS
    Build's iLAPs Client for Deployment with Client Secrets

    .DESCRIPTION
    Build's iLAPs Client for Deployment with Client Secrets

    .PARAMETER

    .EXAMPLE

    .NOTES
    Author: Dhruv Bhavsar
    Date: 27-05-2020
    Last Updated: 27-05-2020
#>

################################################
<# Parameters - Start #>

[CmdletBinding()]
    
Param
(
    #Run Script In Development Mode
    [parameter(Mandatory = $false)][string]$BuildEnvironment = "Production",
    [parameter(Mandatory = $false)][bool]$BuildAdminInterfaceOnly = $false
)

<# Parameters - End #>
################################################

<# Functions - Start #>
Function Write-Log {
    [CmdletBinding()]
    
    Param
    (
        [parameter(Mandatory = $true)][string]$Text,
        [parameter(Mandatory = $false)][string][ValidateSet("Information", "Error", "Warning")]$Status = "Information"
    )

    #Construct output.
    $Output = ("[" + (((Get-Date).ToShortDateString()) + "][" + (Get-Date).ToLongTimeString()) + "][" + $Status + "] " + $Text);
    
    #Output.
    Return Write-Output $Output;
}

<# Functions - End #>
################################################
<# Main - Start #>

Write-Log -Text "CURRENT BUILD ENVIRONMENT $($BuildEnvironment.ToUpper())";
Write-Log -Text "Clean Build Output Folder";
Remove-Item './Output' -Recurse -Force -ErrorAction Ignore;
New-Item -Path 'Output' -ItemType Directory;
Write-Log -Text "Copy Base Powershell scripts to Output Folder";
Copy-Item "./Scripts/*" -Destination './Output';
$installationFiles = Get-ChildItem ./Output * -rec
$buildSettings = Get-Content -Path "./settings.$($BuildEnvironment.ToLower()).local.json" -Raw | ConvertFrom-JSON;
foreach ($file in $installationFiles) {
    Write-Log -Text "Adding Build Secrets to file $file";

    $Content = (Get-Content $file.PSPath -Raw);
    foreach ($item in $buildSettings.psobject.Members) {
        #If added to handle built in PSObject Method Exclusions
        If ($item.Value.GetType().ToString() -eq "System.String") {
            $Content = $Content -replace $item.Name, $item.Value 
        }
    }
    $Content = $Content -replace '\[parameter\(Mandatory=\$true\)\]\[string\]\$SecretKey', '[parameter(Mandatory=$false)][string]$SecretKey';
    $Content = $Content -replace '\[parameter\(Mandatory=\$true\)\]\[string\]\$AzureEndpoint', '[parameter(Mandatory=$false)][string]$AzureEndpoint';
    $Content = $Content -replace '\[parameter\(Mandatory=\$true\)\]\[string\]\$AzureSharedAccessSignature', '[parameter(Mandatory=$false)][string]$AzureSharedAccessSignature';
    $Content = $Content -replace '\[parameter\(Mandatory=\$true\)\]\[string\]\$AzureTable', '[parameter(Mandatory=$false)][string]$AzureTable';
    Write-Log -Text "Save $file With Build Secrets";
    Set-Content $file.PSPath -Value $Content;
}
Write-Log -Text "Copy appsettings.Local.json to Admin Blazor Application";
Remove-Item './IntuneLAPsAdmin/IntuneLAPsAdmin/appsettings.Local.json' -Force -ErrorAction Ignore;
Copy-Item "./Output/admin-appsettings-local.json" -Destination './IntuneLAPsAdmin/IntuneLAPsAdmin/appsettings.Local.json';

If ($BuildAdminInterfaceOnly) {
    Write-Log -Text "Building Admin Blazor Application for Debugging in VSCode";
    $process = Start-Process dotnet.exe -ArgumentList "build .\IntuneLAPsAdmin\IntuneLAPsAdmin.sln -c Debug" -NoNewWindow -PassThru -Wait;
    if ($process.ExitCode -eq 0) {
        Write-Log -Text "Finished Building Admin Blazor Application";
        Exit 0;
    }
}
else {
    Write-Log -Text "Building Admin Blazor Application for Publishing";
    $process = Start-Process dotnet.exe -ArgumentList "publish .\IntuneLAPsAdmin\IntuneLAPsAdmin.sln --output .\Output\Admin -c Release -r win-x86" -NoNewWindow -PassThru -Wait;
    if ($process.ExitCode -eq 0) {
        Write-Log -Text "Zip Admin Blazor Application for Zip Deploy";
        Compress-Archive -Path ".\Output\Admin\*" -DestinationPath ".\Output\AdminUI.zip"
        Write-Log -Text "Clean up Outputs folder";
        Remove-Item -Recurse -Force .\Output\Admin;
        Write-Log -Text "Finished Building iLAPs Client";
    }
}

################################################
<# Main - End #>