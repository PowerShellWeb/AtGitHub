<#
.SYNOPSIS
    Configures the site
.DESCRIPTION
    Configures the site.  
    
    At the point this runs, a $Site dictionary should exist, and it should contain a list of files to build.

    Any *.json, *.psd1, or *.yaml files in the root should have already been loaded into the $Site dictionary.

    Any additional configuration or common initialization should be done here.
#>

#region At Protocol

#region At Protocol Data

# If we have a script root, we'll use it to set the working directory.
if ($psScriptRoot) {Push-Location $psScriptRoot}

# Look up in the path
$parentPath = $PSScriptRoot | Split-Path -Parent
# Find any directories that start with did* in the parent path.
$atDataSetScript = $parentPath | 
    Get-ChildItem -Filter AtGitHub.DataSet.ps1

. $atDataSetScript

if ($site -isnot [Collections.IDictionary]) {
    $site = [Ordered]@{}
}

$site['AtGitHub'] = $site['AtData'] = $atGitHubData
#endregion At Protocol Data

if ($psScriptRoot) {Pop-Location}