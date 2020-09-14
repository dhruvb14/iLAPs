#Requires -Version 3.0
<#

    .SYNOPSIS
    Reset local administrator accounts.

    .DESCRIPTION
    This script reset all locally created user accounts.

    .PARAMETER

    .EXAMPLE

    .NOTES
    Original Author: Alex Ã˜. T. Hansen
    Current Implementation Author: Dhruv Bhavsar
    Date: 19-05-2020
    Last Updated: 19-05-2020

#>

################################################
<# Parameters - Start #>

[CmdletBinding()]
    
Param
(
    #Azure endpoint.
    [parameter(Mandatory=$true)][string]$AzureEndpoint = 'https://Storage-Account-Name.table.Storage-Account-Suffix',
    #Azure Shared Access SIgnature.
    [parameter(Mandatory=$true)][string]$AzureSharedAccessSignature  = 'Table-Object-Read-Update-SAS-Token',
    #Azure Storage Table.
    [parameter(Mandatory=$true)][string]$AzureTable = "Reset-Table-Name",
    #Run Script In Debugger Mode
    [parameter(Mandatory=$false)][bool]$DebugMode = $false
)

<# Parameters - End #>
################################################
<# Bootstrap - Start #>

#Create log folder.
New-Item -ItemType Directory -Force -Path "C:\Logs\Intune LAPS" | Out-Null;

<# Bootstrap - End #>
################################################
<# Input - Start #>

#Schedule Task.
$ScheduleTaskName = "Reset Admin Password Request";
@"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2020-05-18T00:00:00.0000000</Date>
    <Author>Dhruv Bhavsar</Author>
    <URI>\Reset Admin Password Request</URI>
    <Version>1.0</Version>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
    <Repetition>
        <Interval>PT1H</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
    </Repetition>
    <StartBoundary>2020-05-26T11:03:11</StartBoundary>
    <Enabled>true</Enabled>
    <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
    </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
    <RestartOnFailure>
      <Interval>PT1H</Interval>
      <Count>999</Count>
    </RestartOnFailure>
  </Settings>
  <Actions Context="Author">
    <Exec>
        <Command>C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe</Command>
        <Arguments>-ExecutionPolicy Bypass -File "C:\Windows\System32\Check-Reset-LocalAdministratorPassword.ps1"</Arguments>
    </Exec>
  </Actions>
</Task>
"@ | Out-File -FilePath ("$ScheduleTaskName" + ".xml");

#Log.
$LogFile = ("C:\Logs\Intune LAPS\" + ((Get-Date).ToString("ddMMyyyy") + ".log"));

<# Input - End #>
################################################
<# Functions - Start #>

Function Test-InternetConnection {
    [CmdletBinding()]
    
    Param
    (
        [parameter(Mandatory = $true)][string]$Target
    )

    #Test the connection to target.
    $Result = Test-NetConnection -ComputerName ($Target -replace "https://", "") -Port 443 -WarningAction SilentlyContinue;

    #Return result.
    Return $Result;
}

#Insert data to Azure tables.
Function Update-AzureTableData {
    [CmdletBinding()]
    
    Param
    (
        [parameter(Mandatory = $true)][string]$Endpoint,
        [parameter(Mandatory = $true)][string]$SharedAccessSignature,
        [parameter(Mandatory = $true)][string]$Table,
        [parameter(Mandatory = $true)][hashtable]$TableData
    )

    #Create request header.
    $Headers = @{
        "x-ms-date"             = (Get-Date -Format r);
        "x-ms-version"          = "2016-05-31";
        "Accept-Charset"        = "UTF-8";
        "DataServiceVersion"    = "3.0;NetFx";
        "MaxDataServiceVersion" = "3.0;NetFx";
        "Accept"                = "application/json;odata=nometadata"
        "If-Match"              = "*" #Has to Be specified to Allow updating with only Read-Update Token
    };

    #Construct URI.
    $URI = ($Endpoint + "/" + $Table + "/" + $SharedAccessSignature);

    #Convert table data to JSON and encode to UTF8.
    $Body = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $TableData));

    #Insert data to Azure storage table.
    Invoke-WebRequest -Method Put -Uri $URI -Headers $Headers -Body $Body -ContentType "application/json" -UseBasicParsing | Out-Null;
}
Function Get-AzureTableData {
    [CmdletBinding()]
    
    Param
    (
        [parameter(Mandatory = $true)][string]$Endpoint,
        [parameter(Mandatory = $true)][string]$SharedAccessSignature,
        [parameter(Mandatory = $true)][string]$Table
    )

    #Create request header.
    $Headers = @{
        "x-ms-date"             = (Get-Date -Format r);
        "x-ms-version"          = "2016-05-31";
        "Accept-Charset"        = "UTF-8";
        "DataServiceVersion"    = "3.0;NetFx";
        "MaxDataServiceVersion" = "3.0;NetFx";
        "Accept"                = "application/json;odata=nometadata"
    };

    #Construct URI.
    $URI = ($Endpoint + "/" + $Table + "/" + $SharedAccessSignature);

    #Convert table data to JSON and encode to UTF8.
    Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers -ContentType "application/json";
}

Function ConvertTo-HashTable {
    [cmdletbinding()]
     
    Param
    (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        [object]$InputObject,
        [switch]$NoEmpty
    )
     
    Process {
        #Get propery names.
        $Names = $InputObject | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name;

        #Define an empty hash table.
        $Hash = @{ };

        #Go through the list of names and add each property and value to the hash table.
        $Names | ForEach-Object { $Hash.Add($_, $InputObject.$_) };

        #If NoEmpty is set.
        If ($NoEmpty) {
            #Define a new hash.
            $Defined = @{ };

            #Get items from $hash that have values and add to $Defined.
            $Hash.Keys | ForEach-Object {
                #If hash item is not empty.
                If ($Hash.item($_)) {
                    #Add to hashtable.
                    $Defined.Add(($_, $Hash.Item($_)));
                }
            }
            
            #Return hashtable.
            Return $Defined;
        }

        #Return hashtable.
        Return $Hash;
    }
}

Function Test-ScheduleTask {
    [CmdletBinding()]
    
    Param
    (
        [parameter(Mandatory = $true)][string]$Name
    )

    #Create a new schedule object.
    $Schedule = New-Object -com Schedule.Service;
    
    #Connect to the store.
    $Schedule.Connect();

    #Get schedule tak folders.
    $Task = $Schedule.GetFolder("\").GetTasks(0) | Where-Object { $_.Name -eq $Name -and $_.Enabled -eq $true };

    #If the task exists and is enabled.
    If ($Task) {
        #Return true.
        Return $true;
    }
    #If the task doesn't exist.
    Else {
        #Return false.
        Return $false;
    }
}

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
Write-Log -File $LogFile -Status Information -Text "Starting password reset check.";

#Test if the machine have internet connection.
If (!((Test-InternetConnection -Target $AzureEndpoint).TcpTestSucceeded -eq "true")) {
    #Write out to the log file.
    Write-Log -File $LogFile -Status Error -Text "No internet access.";

    #Exit the script with an error.
    Exit 1;
}
Else {
    #Write out to the log file.
    Write-Log -File $LogFile -Status Information -Text "The machine has internet access.";
}

#Check if the Old schedule task exist. If So, Remove it.
If (Test-ScheduleTask -Name $ScheduleTaskName) {
    #Write out to the log file.
    Write-Log -File $LogFile -Status Warning -Text "Removing $ScheduleTaskName Scheduled Task.";

    #Add schedule task.
    UnRegister-ScheduledTask -TaskName $ScheduleTaskName -Confirm:$false;
}
Else {
    #Write out to the log file.
    Write-Log -File $LogFile -Status Warning -Text "$ScheduleTaskName Was not present.";
}

#Check if the schedule task exist.
If (!(Test-ScheduleTask -Name $ScheduleTaskName)) {
    #Write out to the log file.
    Write-Log -File $LogFile -Status Warning -Text "Schedule task doesn't exist.";
    Write-Log -File $LogFile -Status Information -Text "Creating schedule task.";

    #Add schedule task.
    Register-ScheduledTask -Xml (Get-Content ($ScheduleTaskName + ".xml") | Out-String) -TaskName "$ScheduleTaskName" | Out-Null;

    #Write out to the log file.
    Write-Log -File $LogFile -Status Information -Text "Removing schedule task XML file.";

    #Remove XML file.
    Remove-Item ($ScheduleTaskName + ".xml");
}
Else {
    #Write out to the log file.
    Write-Log -File $LogFile -Status Warning -Text "Schedule task already exist.";
}


#Get hostname.
$Hostname = Invoke-Command { hostname };
$Hostname = $Hostname.ToUpper();

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text ("Hostname: " + $Hostname);

#Get serial number.
$SerialNumber = (Get-WmiObject win32_bios).SerialNumber;

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text ("SerialNumber: " + $SerialNumber);

## IMPLEMENT LOGIC TO GO RETRIEVE RESET INFORMATION HERE
$Path = "C:\Windows\system32";
If($DebugMode){
    $Path = "C:\Dev\iLAPS\Output";
}
$Installer = "Reset-LocalAdministratorPassword.ps1";

$SingleItemLookup = $AzureTable + "(PartitionKey='$($Hostname)',RowKey='$($SerialNumber)')";
$item = Get-AzureTableData -Endpoint $AzureEndpoint -SharedAccessSignature $AzureSharedAccessSignature -Table $SingleItemLookup;
If ($item) {
    Write-Log -File $LogFile -Status Information -Text ("Checking if Admin Reset is Required");
    If ($item.NeedsReset) {
        Write-Log -File $LogFile -Status Information -Text ("Admin Reset is Required");
        $ResetRequestDate = [Datetime]::ParseExact($item.ResetRequestedDate, 'yyyy-MM-ddTHH:mm:ssZ', $null);
        $ResetRequestDate = $ResetRequestDate.ToUniversalTime();
        If ($ResetRequestDate.GetType().ToString() -eq "System.DateTime") {
            Write-Log -File $LogFile -Status Information -Text ("Admin Reset is Requested for after $($item.ResetRequestedDate)");
            $currentDate = Get-Date;
            $currentDate = $currentDate.ToUniversalTime();
            If ($currentDate -gt $ResetRequestDate) {
                Write-Log -File $LogFile -Status Information -Text ("Resetting Admin Password at $($currentDate)");
                $process = Start-Process powershell.exe -ArgumentList "-file $($Path)\$($Installer)" -NoNewWindow -PassThru -Wait
                if ($process.ExitCode -eq 0) {
                    $item.NeedsReset = $false;
                    Update-AzureTableData -Endpoint $AzureEndpoint -SharedAccessSignature $AzureSharedAccessSignature -Table $SingleItemLookup -TableData (ConvertTo-HashTable -InputObject $item);
                    Write-Log -File $LogFile -Status Information -Text ("Admin Password Reset Successful");
                }
                else {
                    Write-Log -File $LogFile -Status Information -Text ("Admin Password Reset Failed");
                }
            } 
            else {
                Write-Log -File $LogFile -Status Information -Text ("Admin Password will reset after $($item.ResetRequestedDate)");
            }
        }
    } 
    else {
        Write-Log -File $LogFile -Status Information -Text ("Admin Password does not need reset");
    }
}
else {
    Write-Log -File $LogFile -Status Information -Text ("Admin Password has never been used and does not need reset");
}

<# Main - End #>
################################################