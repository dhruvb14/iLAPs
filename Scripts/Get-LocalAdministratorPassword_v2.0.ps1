#Requires -Version 3.0
<#

    .SYNOPSIS
    Get password for local administrator accounts that was reset with iLAPS.

    .DESCRIPTION
    This script get all locally created user accounts and their passwords intergrated with iLAPS.

    .PARAMETER

    .EXAMPLE

    .NOTES
    Original Author: Alex Ã˜. T. Hansen
    Current Implementation Author: Dhruv Bhavsar and Theron Howton
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
    [parameter(Mandatory = $true)][string]$AzureSharedAccessSignature = 'Table-Object-Read-List-SAS-Token',
    #Azure Storage Table.
    [parameter(Mandatory = $true)][string]$AzureTable = "Admin-Table-Name",
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

#Log.
$LogFilePath = "C:\Logs\Intune Management"
$Solution = "iLaps"
$LogFile = ("$LogFilePath\" + "$Solution" - + ((Get-Date).ToString("yyyyMMdd") + ".log"));

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

#Get data from Azure tables.
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
    $URI = ($Endpoint + "/" + $Table + $SharedAccessSignature);

    #Insert data to Azure storage table.
    $Response = Invoke-WebRequest -Method Get -Uri $URI -Headers $Headers -UseBasicParsing;

    #Return table data.
    Return , ($Response.Content | ConvertFrom-Json).Value;
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

#Decrypt data with a secret key.
Function Get-EncryptedData {
    [CmdletBinding()]
    Param
    (
        $Key,
        $TextInput
    )

    #Decrypt the text input with the secret key.
    $Result = $TextInput | ConvertTo-SecureString -key $Key | ForEach-Object { [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)) };

    #Return the decrypted data.
    Return $Result;
}

<# Functions - End #>
################################################
<# Main - Start #>

#Test if the machine have internet connection.
If (!((Test-InternetConnection -Target $AzureEndpoint).TcpTestSucceeded -eq "true")) {
    #Write out to the log file.
    Write-Log -File $LogFile -Status Error -Text "No internet access.";

    #Exit the script with an error.
    Exit 1;
}

#Secret key.
$EncryptionKey = Set-SecretKey -Key ($SecretKey);

#Get all passwords.
$Data = Get-AzureTableData -Endpoint $AzureEndpoint -SharedAccessSignature $AzureSharedAccessSignature -Table $AzureTable;

#Object array.
$Accounts = @();

#If there is any data.
If ($Data) {
    #Foreach password.
    Foreach ($Account in $Data) {
        #Decrypt password.
        $Password = Get-EncryptedData -Key $EncryptionKey -TextInput $Account.Password;

        #Create a new object.
        $AccountObject = New-Object -TypeName PSObject;

        #Add value to the object.
        Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "SerialNumber" -Value ($Account).SerialNumber;
        Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Hostname" -Value ($Account).Hostname;
        Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Username" -Value ($Account).Account;
        Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Password" -Value ($Password).ToString();
        Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "PasswordChanged" -Value ([datetime]($Account).PasswordChanged);

        #Add to object array.
        $Accounts += $AccountObject;
    }
}
#If no entries are returned.
Else {
    #Create a new object.
    $AccountObject = New-Object -TypeName PSObject;

    #Add value to the object.
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "SerialNumber" -Value "<empty>";
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Hostname" -Value "<empty>";
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Username" -Value "<empty>";
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Password" -Value "<empty>";
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "PasswordChanged" -Value "<empty>";

    #Add to object array.
    $Accounts += $AccountObject;
}

#Create GUI.
$Accounts | Out-GridView -Title "iLAPS" -PassThru;

<# Main - End #>
################################################