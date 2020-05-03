param(
    [Parameter(Mandatory=$true)]
    [string]
    $GalleryApiKey
)

$env:PSModulePath = $env:PSModulePath + [System.IO.Path]::PathSeparator + "$PSScriptRoot"
Publish-Module -Name PSWsl -NuGetApiKey $GalleryApiKey