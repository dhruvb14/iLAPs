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
    <#
     DO NOT MODIFY SECRETS INLINE BELOW
     Follow ReadMe.md and use Build.ps1 
     With a proper settings file to build
     The script properly.
    #>
    #Encryption key.
    [parameter(Mandatory = $true)][string]$SecretKey = "Global-Encryption-Key",
    #Azure endpoint.
    [parameter(Mandatory = $true)][string]$AzureEndpoint = 'https://Storage-Account-Name.table.Storage-Account-Suffix',
    #Azure Shared Access SIgnature.
    [parameter(Mandatory = $true)][string]$AzureSharedAccessSignature = 'Table-Object-Read-Update-SAS-Token',
    #Azure Storage Table.
    [parameter(Mandatory = $true)][string]$AzureTable = "DEM-Table-Name",
    #Run Script In Debugger Mode
    [parameter(Mandatory = $false)][bool]$DebugMode = $false
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
$ScheduleTaskName = "Reset DEM Admin Password Request";
@"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2020-05-18T00:00:00.0000000</Date>
    <Author>Dhruv Bhavsar</Author>
    <URI>\Reset DEM Admin Password Request</URI>
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
      <Command>C:\Windows\System32\DEM-Password-Reset-Script.ps1</Command>
    </Exec>
  </Actions>
</Task>
"@ | Out-File -FilePath ("$ScheduleTaskName" + ".xml");

#Log.
$LogFile = ("C:\Logs\DEM Reset\" + ((Get-Date).ToString("ddMMyyyy") + ".log"));
New-Item -Path 'C:\Logs\DEM Reset\' -ItemType Directory -ErrorAction Ignore;

<# Input - End #>
################################################
<# Functions - Start #>
Function Set-SecretKey {
    [CmdletBinding()]
    Param
    (
        [string]$Key
    )

    #Get key length.
    $Length = $Key.Length;
    
    #Pad length.
    $Pad = 32 - $Length;
    
    #If the length is less than 16 or more than 32.
    If ($Length -ne 32) {
        #Throw exception.
        Throw "SecureKey String must be 32 characters";
    }
    
    #Create a new ASCII encoding object.
    $Encoding = New-Object System.Text.ASCIIEncoding;

    #Get byte array.
    $Bytes = $Encoding.GetBytes($Key + "0" * $Pad);

    #Return byte array.
    Return $Bytes;
}
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

Function New-Password {
    [CmdletBinding(DefaultParameterSetName = 'FixedLength', ConfirmImpact = 'None')]
    [OutputType([String])]
    Param
    (
        # Specifies minimum password length
        [Parameter(Mandatory = $false,
            ParameterSetName = 'RandomLength')]
        [ValidateScript( { $_ -gt 0 })]
        [Alias('Min')] 
        [int]$MinPasswordLength = 12,
        
        # Specifies maximum password length
        [Parameter(Mandatory = $false,
            ParameterSetName = 'RandomLength')]
        [ValidateScript( {
                if ($_ -ge $MinPasswordLength) { $true }
                else { Throw 'Max value cannot be lesser than min value.' } })]
        [Alias('Max')]
        [int]$MaxPasswordLength = 12,

        # Specifies a fixed password length
        [Parameter(Mandatory = $false,
            ParameterSetName = 'FixedLength')]
        [ValidateRange(1, 2147483647)]
        [int]$PasswordLength = 12,
        
        # Specifies an array of strings containing charactergroups from which the password will be generated.
        # At least one char from each group (string) will be used.
        [String[]]$InputStrings = @('abcdefghijkmnpqrstuvwxyz', 'ABCEFGHJKLMNPQRSTUVWXYZ', '123456789', '@#$%^&*!'),

        # Specifies a string containing a character group from which the first character in the password will be generated.
        # Useful for systems which requires first char in password to be alphabetic.
        [String] $FirstChar,
        
        # Specifies number of passwords to generate.
        [ValidateRange(1, 2147483647)]
        [int]$Count = 1
    )
    Begin {
        Function Get-Seed {
            # Generate a seed for randomization
            $RandomBytes = New-Object -TypeName 'System.Byte[]' 4
            $Random = New-Object -TypeName 'System.Security.Cryptography.RNGCryptoServiceProvider'
            $Random.GetBytes($RandomBytes)
            [BitConverter]::ToUInt32($RandomBytes, 0)
        }
    }
    Process {
        For ($iteration = 1; $iteration -le $Count; $iteration++) {
            $Password = @{}
            # Create char arrays containing groups of possible chars
            [char[][]]$CharGroups = $InputStrings

            # Create char array containing all chars
            $AllChars = $CharGroups | ForEach-Object { [Char[]]$_ }

            # Set password length
            if ($PSCmdlet.ParameterSetName -eq 'RandomLength') {
                if ($MinPasswordLength -eq $MaxPasswordLength) {
                    # If password length is set, use set length
                    $PasswordLength = $MinPasswordLength
                }
                else {
                    # Otherwise randomize password length
                    $PasswordLength = ((Get-Seed) % ($MaxPasswordLength + 1 - $MinPasswordLength)) + $MinPasswordLength
                }
            }

            # If FirstChar is defined, randomize first char in password from that string.
            if ($PSBoundParameters.ContainsKey('FirstChar')) {
                $Password.Add(0, $FirstChar[((Get-Seed) % $FirstChar.Length)])
            }
            # Randomize one char from each group
            Foreach ($Group in $CharGroups) {
                if ($Password.Count -lt $PasswordLength) {
                    $Index = Get-Seed
                    While ($Password.ContainsKey($Index)) {
                        $Index = Get-Seed                        
                    }
                    $Password.Add($Index, $Group[((Get-Seed) % $Group.Count)])
                }
            }

            # Fill out with chars from $AllChars
            for ($i = $Password.Count; $i -lt $PasswordLength; $i++) {
                $Index = Get-Seed
                While ($Password.ContainsKey($Index)) {
                    $Index = Get-Seed                        
                }
                $Password.Add($Index, $AllChars[((Get-Seed) % $AllChars.Count)])
            }
            Write-Output -InputObject $( -join ($Password.GetEnumerator() | Sort-Object -Property Name | Select-Object -ExpandProperty Value))
        }
    }
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

Function Set-EncryptedData {
    [CmdletBinding()]
    Param
    (
        $Key,
        [string]$TextInput
    )
    
    #Create a new secure string object.
    $SecureString = New-Object System.Security.SecureString;

    #Convert the text input to a char array.
    $Chars = $TextInput.ToCharArray();
    
    #Foreach char in the array.
    ForEach ($Char in $Chars) {
        #Append the char to the secure string.
        $SecureString.AppendChar($Char);
    }
    
    #Encrypt the data from the secure string.
    $EncryptedData = ConvertFrom-SecureString -SecureString $SecureString -Key $Key;

    #Return the encrypted data.
    return $EncryptedData;
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
Function UpdateAdminPassword {
    [CmdletBinding()]
    
    Param
    (
        [parameter(Mandatory = $true)][psobject]$item
    )
    # Build The URL We are going to push updates to
    $SingleItemLookup = $AzureTable + "(PartitionKey='$($item.PartitionKey)',RowKey='$($item.RowKey)')";
    $currentDate = Get-Date;
    $currentDate = $currentDate.ToUniversalTime();
    $Password = (New-Password -MinPasswordLength 12 -MaxPasswordLength 12);
    #Write out to the log file.
    Write-Log -File $LogFile -Status Information -Text ("Encrypting password for $($item.AccountEmailAddress).");
    #Encrypt password.
    $EncryptionKey = Set-SecretKey -Key ($SecretKey);
    $EncryptedPassword = Set-EncryptedData -Key $EncryptionKey -TextInput $Password;
    If ($DebugMode) {
        Write-Log -File $LogFile -Status Information -Text ("DID NOT EXECUTE COMMAND - Would have Updated Identity $($item.AccountEmailAddress.Split("@")[0]) with Plain Password $($Password)");
    }
    else {
        Set-ADAccountPassword -identity "$($item.AccountEmailAddress.Split("@")[0])" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $Password -Force);
    }
    $item.Password = $EncryptedPassword;
    $item.NeedsReset = $false;
    $item.ScheduledNextChange = (Get-Date).AddMonths(6).ToString("o");
    If ($DebugMode) {
        Write-Log -File $LogFile -Status Information -Text ("DID NOT EXECUTE COMMAND - Would have Updated Azure Table $($AzureTable) with Encrypted Password $($EncryptedPassword) and updated NeedsReset Field to $($item.NeedsReset) and updated ScheduledNextChange field to $($item.ScheduledNextChange)");
    }
    else {
        Update-AzureTableData -Endpoint $AzureEndpoint -SharedAccessSignature $AzureSharedAccessSignature -Table $SingleItemLookup -TableData (ConvertTo-HashTable -InputObject $item);
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

If ($DebugMode) {
    Write-Log -File $LogFile -Status Information -Text ("Running in DEBUG Mode");
}

$items = Get-AzureTableData -Endpoint $AzureEndpoint -SharedAccessSignature $AzureSharedAccessSignature -Table $AzureTable;
ForEach ($item in $items.value) {
    If ($item) {
        Write-Log -File $LogFile -Status Information -Text ("Checking if Admin Reset is Required");
        $ResetRequestDate = [Datetime]::ParseExact($item.ResetRequestedDate, 'yyyy-MM-ddTHH:mm:ssZ', $null);
        $ResetRequestDate = $ResetRequestDate.ToUniversalTime();
        $ScheduledNextChange = [Datetime]::ParseExact($item.ScheduledNextChange, 'yyyy-MM-ddTHH:mm:ssZ', $null);
        $ScheduledNextChange = $ScheduledNextChange.ToUniversalTime();
        $currentDate = Get-Date;
        $currentDate = $currentDate.ToUniversalTime();
        If (($ResetRequestDate.GetType().ToString() -eq "System.DateTime" -And $ScheduledNextChange.GetType().ToString() -eq "System.DateTime") -Or $DebugMode) {
            If (($item.NeedsReset -Or ($currentDate -gt $ScheduledNextChange)) -Or $DebugMode) {
                Write-Log -File $LogFile -Status Information -Text ("Password Reset is Required for $($item.AccountEmailAddress) based on Manual Requested Reset by Admin");
                If (($currentDate -gt $ResetRequestDate -And $item.NeedsReset) -Or $DebugMode) {
                    Write-Log -File $LogFile -Status Information -Text ("DEM Reset is Requested for after $($item.ResetRequestedDate)");
                    Write-Log -File $LogFile -Status Information -Text ("Resetting DEM Password for $($item.AccountEmailAddress) at $($currentDate)");
                    # RUN PASSWORD RESET LOGIC AND UPDATE TABLE
                    UpdateAdminPassword($item);
                } 
                else {
                    If ($currentDate -gt $ScheduledNextChange) {
                        Write-Log -File $LogFile -Status Information -Text ("Password Reset is Required for $($item.AccountEmailAddress) based on Automatic Password Reset Policy");
                        # RUN PASSWORD RESET LOGIC AND UPDATE TABLE
                        UpdateAdminPassword($item);
                    }
                    else {
                        Write-Log -File $LogFile -Status Information -Text ("Admin Password will for $($item.AccountEmailAddress) will reset after $($item.ResetRequestedDate)");
                    }
                }
            }
            else {
                Write-Log -File $LogFile -Status Information -Text ("DEM Password does not need reset for $($item.AccountEmailAddress) until $($item.ResetRequestedDate)");
            }
        }
    }
    else {
        Write-Log -File $LogFile -Status Information -Text ("Admin Password has never been used and does not need reset");
    }
}
<# Main - End #>
################################################