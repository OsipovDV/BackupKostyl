#
# Configuration area
#
$confBackupPath = "\\share\Backup"
$confBackupSystemState = $True
$confFilesToBackup = ""
$confFilesToExclude = ""
$confShareUser = "share\user"
$confSharePwd = "pwd"
$date = Get-Date -format "dd-MM-yyyy_HH-mm"
$computername = $env:COMPUTERNAME
$vhdpath = "$confBackupPath\sysstate-$computername-$date.vhd"

#
# Code area, don't change anything bellow this line
#


# Map network share
$password = ConvertTo-SecureString $confSharePwd -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $confShareUser, $password
New-PSDrive -name NetShare -root $confBackupPath -Credential $cred -PSProvider FileSystem


# Initialize script for diskpart, to create vhd on network share
"CREATE VDISK FILE=$vhdpath type=EXPANDABLE MAXIMUM=2000000" | Out-File -FilePath "C:\_scripts\vhd_templ.txt" -Encoding ascii
"SELECT VDISK FILE=$vhdpath" | Out-File -FilePath "C:\_scripts\vhd_templ.txt" -Encoding ascii -Append
"ATTACH VDISK" | Out-File -FilePath "C:\_scripts\vhd_templ.txt" -Encoding ascii -Append
"CREATE PARTITION PRIMARY" | Out-File -FilePath "C:\_scripts\vhd_templ.txt" -Encoding ascii -Append
"FORMAT FS=NTFS QUICK" | Out-File -FilePath "C:\_scripts\vhd_templ.txt" -Encoding ascii -Append
"ASSIGN LETTER=X" | Out-File -FilePath "C:\_scripts\vhd_templ.txt" -Encoding ascii -Append

diskpart.exe /s "C:\_scripts\vhd_templ.txt"



# Initialize backup settings
$policy = New-WBPolicy
$backupLocation = New-WBBackupTarget -VolumePath X:


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

#
# Start Backup
#
Start-WBBackup -Policy $policy


#
# Backup rotation mechanism
#

<#if ((Get-WBJob -Previous 1).JobState -eq "Completed" -and  (Get-WBJob -Previous 1).HResult -eq 0)
{
    $temp = ($confBackupPath + "\WindowsImageBackup\" + $computername)
    if((Test-Path -Path ($temp + ".2")) -eq $true)
    {
        Remove-Item -Path ($temp + ".2") -Force -Recurse
    }
    

    if((Test-Path -Path ($temp + ".1")) -eq $true)
    {
        Rename-Item -Path ($temp + ".1") -NewName ($temp + ".2") ;
    }
    
    Rename-Item -Path ($temp) -NewName ($temp + ".1") ;
  
}#>

# Initialize script for diskpart, to unmount vhd
"SELECT VDISK FILE=$vhdpath" | Out-File -FilePath "C:\_scripts\vhd_templ.txt" -Encoding ascii
"DETACH VDISK" | Out-File -FilePath "C:\_scripts\vhd_templ.txt" -Encoding ascii -Append
diskpart.exe /s "C:\_scripts\vhd_templ.txt"


# Unmap network share
Remove-PSDrive -name NetShare

