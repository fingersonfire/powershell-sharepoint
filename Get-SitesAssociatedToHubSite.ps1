#requires -version 4
<#
.SYNOPSIS
  Retreive sites associated to a Hub Site

.DESCRIPTION
  Source : https://engineerer.ch/2019/07/04/get-all-sites-associated-with-a-sharepoint-online-hub-site/

.PARAMETER None

.INPUTS
  Tenant ID and Hubsite name

.OUTPUTS
  List of sites in the console

.NOTES
  Version:        1.0
  Author:         Engineerer
  Creation Date:  04/07/2019
  Purpose/Change: Initial script development

.EXAMPLE
  Get-SitesAssociatedToHubSite.ps1
  
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

Connect-PnPOnline -Url https://[tenant]-admin.sharepoint.com

# get the hub site id
$hubSite = Get-PnPTenantSite "https://[tenant].sharepoint.com/sites/intranet"
$hubSiteId = $hubSite.HubSiteId

# get all sites associated to the hub
$sites = Get-PnPTenantSite -Detailed
$sites | select url | % { 
  $s = Get-PnPTenantSite $_.url 
  if($s.hubsiteid -eq $hubSiteId){
    write-host $s.url
  }
}