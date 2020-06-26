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
    [parameter(Mandatory=$true)][string]$SecretKey = "Global-Encryption-Key",
    #Run Script In Debugger Mode
    [parameter(Mandatory=$true)][string]$PW
)


<# Input - End #>
################################################
<# Functions - Start #>
Function Set-SecretKey
{
    [CmdletBinding()]
    Param
    (
        [string]$Key
    )

    #Get key length.
    $Length = $Key.Length;
    
    #Pad length.
    $Pad = 32-$Length;
    
    #If the length is less than 16 or more than 32.
    If($Length -ne 32)
    {
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

Function Set-EncryptedData
{
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
    ForEach($Char in $Chars)
    {
        #Append the char to the secure string.
        $SecureString.AppendChar($Char);
    }
    
    #Encrypt the data from the secure string.
    $EncryptedData = ConvertFrom-SecureString -SecureString $SecureString -Key $Key;

    #Return the encrypted data.
    return $EncryptedData;
}

<# Functions - End #>
################################################
<# Main - Start #>
    $EncryptionKey = Set-SecretKey -Key ($SecretKey);
    $EncryptedPassword = Set-EncryptedData -Key $EncryptionKey -TextInput $PW;
    Write-Output $EncryptedPassword;
<# Main - End #>
################################################