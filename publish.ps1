param(
    [Parameter(Mandatory=$true)]
    [string]
    $GalleryApiKey
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$env:PSModulePath = $env:PSModulePath + [System.IO.Path]::PathSeparator + "$(Get-Location)"
Publish-Module -Name PsUWI -NuGetApiKey $GalleryApiKey