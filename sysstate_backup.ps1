#
# Configuration area
#
$confBackupPath = "\\share\Backup"
$confBackupSystemState = $True
$confFilesToBackup = ""
$confFilesToExclude = ""
$confShareUser = "share\user"
$confSharePwd = "pwd"

#
# Code area, don't change anything bellow this line
#

$password = ConvertTo-SecureString $confSharePwd -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $confShareUser, $password

# used for SMB Share
New-PSDrive -name BackupDrive -root $confBackupPath -Credential $cred -PSProvider FileSystem


$policy = New-WBPolicy
$backupLocation = New-WBBackupTarget -networkpath $confBackupPath


if($confFilesToBackup)
{
foreach ( $file in $confFilesToBackup.split(";"))
    {
	    $fileSpec = New-WBFileSpec -FileSpec $file
	    Add-WBFileSpec -Policy $policy -FileSpec $filespec
    }
}

if($confFilesToExclude)
{
    foreach ( $file in $confFilesToExclude.split(";"))
    {
    	$fileSpec = New-WBFileSpec -Exclude $file
        Add-WBFileSpec -Policy $policy -FileSpec $filespec
    }
}



if($confBackupSystemState) 
{
	Add-WBSystemState -Policy $policy
}

Add-WBBackupTarget -Policy $policy -Target $backupLocation
Set-WBVssBackupOptions -Policy $policy -Vssfull
Start-WBBackup -Policy $policy

if ((Get-WBJob -Previous 1).JobState -eq "Completed")
{
    $temp = ($confBackupPath + "\WindowsImageBackup\" + $env:COMPUTERNAME)
    if((Test-Path -Path ($temp + ".2")) -eq $true)
    {
        Remove-Item -Path ($temp + ".2") -Force -Recurse
    }
    

    if((Test-Path -Path ($temp + ".1")) -eq $true)
    {
        Rename-Item -Path ($temp + ".1") -NewName ($temp + ".2") ;
    }
    
    Rename-Item -Path ($temp) -NewName ($temp + ".1") ;
  
}
#
Remove-PSDrive -name BackupDrive

