param(
# One or more file paths to build.
[string[]]
$FilePath,

# If set, will generate an archive.zip file of the current directory.
[switch]
$Archive
)

# Push into the script root directory
if ($PSScriptRoot) { Push-Location $PSScriptRoot }

# Creation of a sitewide object to hold configuration information.
$Site = [Ordered]@{}
$Site.Files = 
    if ($filePath) { Get-ChildItem -Recurse -File -Path $FilePath } 
    else { Get-ChildItem -Recurse -File }

$Site.PSScriptRoot = "$PSScriptRoot"

#region Common Functions and Filters
$functionFileNames = 'functions', 'function', 'filters', 'filter'
$functionPattern   = "(?>$($functionFileNames -join '|'))\.ps1$"
$functionFiles     = Get-ChildItem -Path $psScriptRoot |
    Where-Object Name -Match $functionPattern

foreach ($file in $functionFiles) {
    # If we have a file with the name function or functions, we'll use it to set the site configuration.
    . $file.FullName
}
#endregion Common Functions and Filters

# Set an alias to buildFile.ps1
Set-Alias BuildFile ./buildFile.ps1

# If we have an event path,
$gitHubEvent =
    if ($env:GITHUB_EVENT_PATH) {
        # all we need to do to serve it is copy it.
        Copy-Item $env:GITHUB_EVENT_PATH .\gitHubEvent.json

        # and we can assign it to a variable, so you we can use it in any files we build.
        Get-Content -Path .\gitHubEvent.json -Raw | ConvertFrom-Json
    }

# If we have a CNAME, read it, trim it, and update the site object.
if (Test-Path 'CNAME') {
    $Site.CNAME = $CNAME = (Get-Content -Path 'CNAME' -Raw).Trim()
    $Site.RootUrl = "https://$CNAME/"
} elseif (
    ($site.PSScriptRoot | Split-Path -Leaf) -like '*.*'
) {
    $site.CNAME = $CNAME = ($site.PSScriptRoot | Split-Path -Leaf)
    $site.RootUrl = "https://$CNAME/"
}

# If we have a config.json file, it can be used to set the site configuration.
if (Test-Path 'config.json') {
    $siteConfig = Get-Content -Path 'config.json' -Raw | ConvertFrom-Json
    foreach ($property in $siteConfig.psobject.properties) {
        $Site[$property.Name] = $property.Value
    }
}

# If we have a config.psd1 file, we'll use it to set the site configuration.
if (Test-Path 'config.psd1') {
    $siteConfig = Import-LocalizedData -FileName 'config.psd1' -BaseDirectory $PSScriptRoot
    foreach ($property in $siteConfig.GetEnumerator()) {
        $Site[$property.Key] = $property.Value
    }
}

if (Test-Path 'config.yaml') {
    $siteConfig = Get-Item 'config.yaml' | from_yaml
    foreach ($property in $siteConfig.GetEnumerator()) {
        $Site[$property.Name] = $property.Value
    }
}

# If we have a config.ps1 file,
if (Test-Path 'config.ps1') {
    # Get the script command
    $configScript = Get-Command -Name './config.ps1'
    # and install any requirements it has.
    $configScript | RequireModule
    # run it, and let it configure anything it chooses to.
    . $configScript
}

# Start the clock
$site['LastBuildTime'] = $lastBuildTime = [DateTime]::Now
#region Build Files

# Start the clock on the build process
$buildStart = [DateTime]::Now
# pipe every file we find to buildFile
try {
    $Site.Files | . buildFile
} catch {
    $errorInfo = $_
    "##[error]$($errorInfo | Out-String)"
    throw $errorInfo
}


# and stop the clock
$buildEnd = [DateTime]::Now

#endregion Build Files

# If we have changed directories, we need to push back into the script root directory.
if ($PSScriptRoot -and "$PSScriptRoot" -ne "$pwd") {
    Push-Location $psScriptRoot
}

#region lastBuild.json
# We create a new object each time, so we can use it to compare to the last build.
$newLastBuild = [Ordered]@{
    LastBuildTime = $lastBuildTime
    BuildDuration = $buildEnd - $buildStart
    Message = 
        if ($gitHubEvent.commits) { 
            $gitHubEvent.commits[-1].Message
        } elseif ($gitHubEvent.schedule) {
            "Ran at $([DateTime]::Now.ToString('o')) on $($gitHubEvent.schedule)"
        } else {
            'On Demand'
        }
}

# If we have a CNAME, we can use it to get the last build time from the server.
$lastBuild =
    try {
        Invoke-RestMethod -Uri "https://$CNAME/lastBuild.json" -ErrorAction Ignore
    } catch {
        Write-Warning ($_ | Out-String)
    }

# If we could get the last build time, we can use it to calculate the time since the last build.
if ($lastBuild) {
    $newLastBuild.TimeSinceLastBuild = $lastBuildTime - $lastBuild.LastBuildTime
}

# Save the build time to a file.
$newLastBuild | ConvertTo-Json -Depth 2 > lastBuild.json
#endregion lastBuild.json

#region archive.zip
if ($site.Archive) {
    #Create an archive of the current deployment.
    Compress-Archive -Path $pwd -DestinationPath "archive.zip" -CompressionLevel Optimal -Force
    #endregion archive.zip
}
if ($PSScriptRoot) { Pop-Location }
