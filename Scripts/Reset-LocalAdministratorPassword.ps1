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
    #Encryption key.
    [parameter(Mandatory = $true)][string]$SecretKey = "Global-Encryption-Key",
    #Azure endpoint.
    [parameter(Mandatory = $true)][string]$AzureEndpoint = 'https://Storage-Account-Name.table.Storage-Account-Suffix',
    #Azure Shared Access SIgnature.
    [parameter(Mandatory = $true)][string]$AzureSharedAccessSignature = 'Table-Object-Add-Create-SAS-Token',
    #Azure Storage Table.
    [parameter(Mandatory = $true)][string]$AzureTable = "Admin-Table-Name",
    #Run Script In Debugger Mode
    [parameter(Mandatory = $false)][bool]$DebugMode = $false
)

<# Parameters - End #>
################################################
<# Bootstrap - Start #>
$CompanyName = "Company-Name";
#Create log folder.
New-Item -ItemType Directory -Force -Path "C:\Logs\Intune LAPS" | Out-Null;

<# Bootstrap - End #>
################################################
<# Input - Start #>

#Schedule Task.
$ScheduleTaskName = "iLAPS Reset Admin Password v1.0";
@"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2020-05-18T00:00:00.0000000</Date>
    <Author>Dhruv Bhavsar</Author>
    <URI>\iLAPS Reset Admin Password v1.0</URI>
    <Version>1.0</Version>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>2020-05-18T00:00:00.0000000</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByMonth>
        <DaysOfMonth>
          <Day>01</Day>
        </DaysOfMonth>
        <Months>
          <January/>
          <February/>
          <March/>
          <April/>
          <May/>
          <June/>
          <July/>
          <August/>
          <September/>
          <October/>
          <November/>
          <December/>
        </Months>
      </ScheduleByMonth>
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
        <Arguments>-ExecutionPolicy Bypass -File "C:\Windows\System32\Reset-LocalAdministratorPassword.ps1"</Arguments>
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

#Generate passwords.
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
        [int]$MinPasswordLength = 16,
        
        # Specifies maximum password length
        [Parameter(Mandatory = $false,
            ParameterSetName = 'RandomLength')]
        [ValidateScript( {
                if ($_ -ge $MinPasswordLength) { $true }
                else { Throw 'Max value cannot be lesser than min value.' } })]
        [Alias('Max')]
        [int]$MaxPasswordLength = 20,

        # Specifies a fixed password length
        [Parameter(Mandatory = $false,
            ParameterSetName = 'FixedLength')]
        [ValidateRange(1, 2147483647)]
        [int]$PasswordLength = 20,
        
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
Function Add-AzureTableData {
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
    };

    $URI

    #Construct URI.
    $URI = ($Endpoint + "/" + $Table + "/" + $SharedAccessSignature);

    #Convert table data to JSON and encode to UTF8.
    $Body = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $TableData));

    #Insert data to Azure storage table.
    Invoke-WebRequest -Method Post -Uri $URI -Headers $Headers -Body $Body -ContentType "application/json" -UseBasicParsing | Out-Null;
}

#Generate a secret key.
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

#Encrypt data with a secret key.
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
        $Hash = @{};

        #Go through the list of names and add each property and value to the hash table.
        $Names | ForEach-Object { $Hash.Add($_, $InputObject.$_) };

        #If NoEmpty is set.
        If ($NoEmpty) {
            #Define a new hash.
            $Defined = @{};

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

Function Get-LocalGroupMembers {
    [CmdletBinding()]
    
    Param
    (
        [parameter(Mandatory = $true)][string]$LocalGroup
    )

    #Get local machine name.
    $Machine = $env:COMPUTERNAME;

    #Get group through ADSI.
    $Group = [ADSI]"WinNT://$Machine/$LocalGroup,group";

    #Get members.
    $Members = $Group.psbase.Invoke("Members");

    #Get members of the group.
    $GroupMembers = $Members | ForEach-Object { $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null) };

    #Return group members.
    Return $GroupMembers;
}

Function Get-LocalUsers {
    [CmdletBinding()]
    
    #Get local user accounts.
    $LocalUserAccounts = Get-WmiObject -Class Win32_UserAccount -Filter  "LocalAccount='True'";

    #Object array.
    $Accounts = @();

    #Foreach local user account.
    Foreach ($LocalUserAccount in $LocalUserAccounts) {
        #Split the SID to get the last octet.
        $SIDSplit = ((($LocalUserAccount.SID -split "-")[-1]).ToString());

        #If the SID last octet starts with 1, or is 500.
        If (($SIDSplit.StartsWith("1")) -or ($SIDSplit -eq "500")) {
            #Add to the object array.    
            $Accounts += $LocalUserAccount;
        }
    }

    #Return accounts.
    Return $Accounts;
}

<# Functions - End #>
################################################
<# Main - Start #>

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text "Starting password reset.";

#Test if the machine have internet connection.
If (!((Test-InternetConnection -Target $AzureEndpoint).TcpTestSucceeded -eq "true")) {
    #Write out to the log file.
    Write-Log -File $LogFile -Status Error -Text "No internet access.";

    #Exit the script with an error.
    Exit 1;
}
Else {
    #Write out to the log file.
    Write-Log -File $LogFile -Status Information -Text "The machine have internet access.";
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

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text "Setting encryption key.";

#Secret key.
$EncryptionKey = Set-SecretKey -Key ($SecretKey);

#Get hostname.
$Hostname = Invoke-Command { hostname };
$Hostname = $Hostname.ToUpper();


#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text ("Hostname: " + $Hostname);

#Get serial number.
$SerialNumber = (Get-WmiObject win32_bios).SerialNumber;

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text ("SerialNumber: " + $SerialNumber);

#Get machine guid.
$MachineGuid = Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid;

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text ("MachineGuid: " + $MachineGuid);

#Get public IP.
$PublicIP = ((Invoke-RestMethod "http://ipinfo.io/json").IP);

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text ("PublicIP: " + $PublicIP);

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text ("Getting all local users.");

#Get all local users.
$LocalUsers = Get-LocalUsers;

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text ("Getting all members of administrators.");

#Get members of the administrator group.
$LocalGroupUsers = Get-LocalGroupMembers -LocalGroup "Administrators";

#Object array.
$Accounts = @();
$LocalAdministrators = @();

#Foreach local user.
Foreach ($LocalUser in $LocalUsers) {
    #If the local user is in the group.
    If ($LocalUser | Where-Object { $_.Name -in $LocalGroupUsers }) {
        #Add user to the object array.
        $LocalAdministrators += $LocalUser;
    }
}

#Foreach administrator.
Foreach ($LocalAdministrator in $LocalAdministrators) {
    #Generate GUID.
    $GUID = (New-Guid).Guid;

    #Write out to the log file.
    Write-Log -File $LogFile -Status Information -Text ("Looping through local administrator '" + ($LocalAdministrator.Name).ToString() + "'.");
    Write-Log -File $LogFile -Status Information -Text ("Generating new password for '" + ($LocalAdministrator.Name).ToString() + "'.");

    #Generate password.
    $Password = (New-Password -MinPasswordLength 20 -MaxPasswordLength 20);
    
    #Write out to the log file.
    Write-Log -File $LogFile -Status Information -Text ("Encrypting password for '" + ($LocalAdministrator.Name).ToString() + "'.");

    #Encrypt password.
    $EncryptedPassword = Set-EncryptedData -Key $EncryptionKey -TextInput $Password;

    #Get date.
    $Time = (Get-Date);

    #Unix time.
    $UnixTime = [System.Math]::Truncate((Get-Date -Date (Get-Date).ToUniversalTime() -UFormat %s));

    #Reset the password and change the description.
    $SetLocalUserError = $null
    $NetUserError = $null
    Try { Set-LocalUser -SID $($LocalAdministrator.SID) -Password $($Password | ConvertTo-SecureString -AsPlainText -Force) -Description ("Managed by " + $CompanyName) -Confirm:$false -ErrorAction Stop; }
    Catch {
        $SetLocalUserError = $_.Exception.Message
        Write-Log -File $LogFile -Status Information -Text ("Error Setting password for '" + ($LocalAdministrator.Name).ToString() + "' via Powershell. Error: $SetLocalUserError. Will attempt with Net User command");    
        Try { Net User $($LocalAdministrator.Name) $Password }
        Catch {
            $NetUserError = $True
            Write-Log -File $LogFile -Status Information -Text ("Error Setting password for '" + ($LocalAdministrator.Name).ToString() + "' via Net User command Error: $NetUserError. Password Failed even though iLAPS may show a new password ")
        }
    }
    if (!$SetLocalUserError) {
        #Write out to the log file.
        Write-Log -File $LogFile -Status Information -Text ("Set password for '" + ($LocalAdministrator.Name).ToString() + "' via PowerShell without Error ");
    }
    elseif (!$NetUserError) {
        #Write out to the log file.
        Write-Log -File $LogFile -Status Information -Text ("Set password for '" + ($LocalAdministrator.Name).ToString() + "' via Net User command without Error ");
    }
        
    #Create a new object.
    $AccountObject = New-Object -TypeName PSObject;

    #Add value to the object.
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "PartitionKey" -Value ($GUID).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "RowKey" -Value ($UnixTime).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "MachineGuid" -Value ($MachineGuid).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "SerialNumber" -Value ($SerialNumber).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Hostname" -Value ($Hostname).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Account" -Value ($LocalAdministrator.Name).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "SID" -Value ($LocalAdministrator.SID).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Password" -Value ($EncryptedPassword).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "PasswordChanged" -Value ($Time).ToString("o");
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "PasswordNextChange" -Value ($Time).AddMonths(1).ToString("o");
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "PublicIP" -Value ($PublicIP).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Enabled" -Value (Get-LocalUser -Name $LocalAdministrator.Name).Enabled;
    
    #Add the object to the array.
    $Accounts += $AccountObject;
}

#Foreach account.
Foreach ($Account in $Accounts) {
    #Write out to the log file.
    Write-Log -File $LogFile -Status Information -Text ("Uploading data to Azure tables for '" + ($Account.Account).ToString() + "'.");

    #Insert data to the Azure table.
    Add-AzureTableData -Endpoint $AzureEndpoint -SharedAccessSignature $AzureSharedAccessSignature -Table $AzureTable -TableData (ConvertTo-HashTable -InputObject $Account);
}

#Write out to the log file.
Write-Log -File $LogFile -Status Information -Text "Stopping password reset.";

<# Main - End #>
################################################