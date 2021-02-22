#requires -version 4
<#
.SYNOPSIS
  Transfer all OneDrive files to another user via PowerShell

.DESCRIPTION

  Backup FIRST !!!!

  During the offboarding of an Office 365 user, you may be required to make a copy of their OneDrive files or transfer ownership of the files to someone else. This can be a laborious process, requiring you to log into the departing users OneDrive and downloading, transferring or sharing their data manually.

  The good news is, we can do this with PowerShell. The below script makes it relatively easy to copy a user’s entire OneDrive directory into a subfolder in another user’s OneDrive.

  The bad news is, there are a few things you’ll need to consider before you use it:
  
  Things to keep in mind
    This could take a while.
    Each file or folder takes at least a second or two to process. If your departing user has tens of thousands of files, and time is not on your side, you may want to use another method.
    It uses your connection
    It downloads the files before uploading them to the other user’s OneDrive. If your connection is slow, and you’re moving large files you might want to leave this running on a cloud hosted server.
    It can’t move files larger than 250MB
    A limitation of this PowerShell module is that it can’t send files larger than 250MB to SharePoint. This script will make a note of these files and export a list of them to c:\temp\largefiles.txt in case you want to move them manually.
    No Two Factor Authentication
    This script doesn’t work with multifactor authentication on the admin account. You may want to create a temporary admin without MFA for this purpose.


.NOTES
  Version:        1.0
  Author:         Elliot Munro
  Creation Date:  2017-10-17
  Purpose/Change: Initial script development
  Source : https://gcits.com/knowledge-base/transfer-users-onedrive-files-another-user-via-powershell/

.EXAMPLE
  Copy-OneDriveToOneDrive.ps1
  Please follow on screen instructions
#>

#---------------------------------------------------------[Script Parameters]------------------------------------------------------

Param (
  #Script parameters go here
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'

#Import Modules & Snap-ins

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Any Global Declarations go here

#-----------------------------------------------------------[Functions]------------------------------------------------------------



#-----------------------------------------------------------[Execution]------------------------------------------------------------

$departinguser = Read-Host "Enter departing user's email"
$destinationuser = Read-Host "Enter destination user's email"
$globaladmin = Read-Host "Enter the username of your Global Admin account"
$credentials = Get-Credential -Credential $globaladmin
Connect-MsolService -Credential $credentials
 
$InitialDomain = Get-MsolDomain | Where-Object {$_.IsInitial -eq $true}
  
$SharePointAdminURL = "https://$($InitialDomain.Name.Split(".")[0])-admin.sharepoint.com"
  
$departingUserUnderscore = $departinguser -replace "[^a-zA-Z]", "_"
$destinationUserUnderscore = $destinationuser -replace "[^a-zA-Z]", "_"
  
$departingOneDriveSite = "https://$($InitialDomain.Name.Split(".")[0])-my.sharepoint.com/personal/$departingUserUnderscore"
$destinationOneDriveSite = "https://$($InitialDomain.Name.Split(".")[0])-my.sharepoint.com/personal/$destinationUserUnderscore"
Write-Host "`nConnecting to SharePoint Online" -ForegroundColor Blue
Connect-SPOService -Url $SharePointAdminURL -Credential $credentials
  
Write-Host "`nAdding $globaladmin as site collection admin on both OneDrive site collections" -ForegroundColor Blue
# Set current admin as a Site Collection Admin on both OneDrive Site Collections
Set-SPOUser -Site $departingOneDriveSite -LoginName $globaladmin -IsSiteCollectionAdmin $true
Set-SPOUser -Site $destinationOneDriveSite -LoginName $globaladmin -IsSiteCollectionAdmin $true
  
Write-Host "`nConnecting to $departinguser's OneDrive via SharePoint Online PNP module" -ForegroundColor Blue
  
Connect-PnPOnline -Url $departingOneDriveSite -Credentials $credentials
  
Write-Host "`nGetting display name of $departinguser" -ForegroundColor Blue
# Get name of departing user to create folder name.
$departingOwner = Get-PnPSiteCollectionAdmin | Where-Object {$_.loginname -match $departinguser}
  
# If there's an issue retrieving the departing user's display name, set this one.
if ($departingOwner -contains $null) {
    $departingOwner = @{
        Title = "Departing User"
    }
}
  
# Define relative folder locations for OneDrive source and destination
$departingOneDrivePath = "/personal/$departingUserUnderscore/Documents"
$destinationOneDrivePath = "/personal/$destinationUserUnderscore/Documents/$($departingOwner.Title)'s Files"
$destinationOneDriveSiteRelativePath = "Documents/$($departingOwner.Title)'s Files"
  
Write-Host "`nGetting all items from $($departingOwner.Title)" -ForegroundColor Blue
# Get all items from source OneDrive
$items = Get-PnPListItem -List Documents -PageSize 1000
  
$largeItems = $items | Where-Object {[long]$_.fieldvalues.SMTotalFileStreamSize -ge 261095424 -and $_.FileSystemObjectType -contains "File"}
if ($largeItems) {
    $largeexport = @()
    foreach ($item in $largeitems) {
        $largeexport += "$(Get-Date) - Size: $([math]::Round(($item.FieldValues.SMTotalFileStreamSize / 1MB),2)) MB Path: $($item.FieldValues.FileRef)"
        Write-Host "File too large to copy: $($item.FieldValues.FileRef)" -ForegroundColor DarkYellow
    }
    $largeexport | Out-file C:\temp\largefiles.txt -Append
    Write-Host "A list of files too large to be copied from $($departingOwner.Title) have been exported to C:\temp\LargeFiles.txt" -ForegroundColor Yellow
}
  
$rightSizeItems = $items | Where-Object {[long]$_.fieldvalues.SMTotalFileStreamSize -lt 261095424 -or $_.FileSystemObjectType -contains "Folder"}
  
Write-Host "`nConnecting to $destinationuser via SharePoint PNP PowerShell module" -ForegroundColor Blue
Connect-PnPOnline -Url $destinationOneDriveSite -Credentials $credentials
  
Write-Host "`nFilter by folders" -ForegroundColor Blue
# Filter by Folders to create directory structure
$folders = $rightSizeItems | Where-Object {$_.FileSystemObjectType -contains "Folder"}
  
Write-Host "`nCreating Directory Structure" -ForegroundColor Blue
foreach ($folder in $folders) {
    $path = ('{0}{1}' -f $destinationOneDriveSiteRelativePath, $folder.fieldvalues.FileRef).Replace($departingOneDrivePath, '')
    Write-Host "Creating folder in $path" -ForegroundColor Green
    $newfolder = Ensure-PnPFolder -SiteRelativePath $path
}
  
 
Write-Host "`nCopying Files" -ForegroundColor Blue
$files = $rightSizeItems | Where-Object {$_.FileSystemObjectType -contains "File"}
$fileerrors = ""
foreach ($file in $files) {
      
    $destpath = ("$destinationOneDrivePath$($file.fieldvalues.FileDirRef)").Replace($departingOneDrivePath, "")
    Write-Host "Copying $($file.fieldvalues.FileLeafRef) to $destpath" -ForegroundColor Green
    $newfile = Copy-PnPFile -SourceUrl $file.fieldvalues.FileRef -TargetUrl $destpath -OverwriteIfAlreadyExists -Force -ErrorVariable errors -ErrorAction SilentlyContinue
    $fileerrors += $errors
}
$fileerrors | Out-File c:\temp\fileerrors.txt
  
# Remove Global Admin from Site Collection Admin role for both users
Write-Host "`nRemoving $globaladmin from OneDrive site collections" -ForegroundColor Blue
Set-SPOUser -Site $departingOneDriveSite -LoginName $globaladmin -IsSiteCollectionAdmin $false
Set-SPOUser -Site $destinationOneDriveSite -LoginName $globaladmin -IsSiteCollectionAdmin $false
Write-Host "`nComplete!" -ForegroundColor Green
