function New-UbuntuWSLInstance {
  <#
    .SYNOPSIS
        Create a new Ubuntu instance on WSL
    .DESCRIPTION
        Create a new Ubuntu instance on WSL. Windows 10 2004 only for now.
    .PARAMETER Release
        The Ubuntu release you want to use to create the instance. Default is focal.
    .PARAMETER Version
        The WSL version you want to use. Default is 1.
    .PARAMETER Force
        If specified, a new WSL tarball will always be downloaded even if it exists.
    .PARAMETER NoUpdate
        If specified, it will not update during the creation.
    .PARAMETER RootOnly
        If specified, no new user will be created.
    .PARAMETER EnableSource
        If specified, all source repositories in `/etc/apt/sources.list` will be enabled.
    .PARAMETER EnableProposed
        If specified, Ubuntu Proposed repository will be enabled. By default selective is enabled.
    .PARAMETER DisableSelective
        If specified, Selective Proposed repostiory will be diabled.
    .PARAMETER AdditionalPPA
        The PPA you want to include by default. Separate each PPA by comma.
    .EXAMPLE
        New-UbuntuWSLInstance -Release bionic
        # Create a Ubuntu Bionic instance on WSL1
    .EXAMPLE
        New-UbuntuWSLInstance -Release xenial -Version 2 -RootOnly
        # Create an Ubuntu Xenial instance on WSL2 without creating a user account
    .EXAMPLE
        New-UbuntuWSLInstance -Version 2 -NoUpdate
        # Create an Ubuntu Focal instance on WSL2 without any update
    .EXAMPLE
        New-UbuntuWSLInstance -Release eoan -Force
        # Create an Ubuntu Eoan instance on WSL1 and download the WSL tarball even if it already exists
    .LINK
        https://github.com/patrick330602/PsUWI
    #>
  [cmdletbinding()]
  Param (

    [Parameter(Mandatory = $false)]
    [string]$Release = 'focal',
    [Parameter(Mandatory = $false)]
    [ValidateSet('1', '2')]
    [string]$Version = '2',
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    [Parameter(Mandatory = $false)]
    [switch]$NoUpdate,
    [Parameter(Mandatory = $false)]
    [switch]$RootOnly,
    [Parameter(Mandatory = $false)]
    [string]$AdditionalPPA,
    [Parameter(Mandatory = $false)]
    [switch]$EnableSource,
    [Parameter(Mandatory = $false)]
    [switch]$EnableProposed,
    [Parameter(Mandatory = $false)]
    [switch]$DisableSelective
  )
  Process {
    Write-Host "# Let the journey begins!" -ForegroundColor DarkYellow

    $TmpName = -join ((65..90) + (97..122) | Get-Random -Count 10 | ForEach-Object { [char]$_ })

    $SysArchName = ($env:PROCESSOR_ARCHITECTURE).ToLower()
    if ( -not ( ( $SysArchName -eq "amd64" ) -or ( $SysArchName -eq "arm64" ) ) ) {
      throw [System.NotSupportedException] "The architecture $SysArchName is not supported."
    }
    if ( ( $Release -eq "xenial" ) -and ( $SysArchName -eq "arm64" ) ) {
      throw [System.NotSupportedException] "Ubuntu Xenial does not support architecture arm64."
    }
    Write-Host "# Your system architecture is $SysArchName" -ForegroundColor DarkYellow
    
    $HomePath = $env:HOME
    if (-not $HomePath) {
      $HomePath = "$($env:HOMEDRIVE)$($env:HOMEPATH)"
    }

    if ( -not (Test-Path -Path "$HomePath\.mbw" -PathType Container ) ) {
      mkdir -Path "$HomePath\.mbw" | Out-Null
    }

    if ( -not (Test-Path -Path "$HomePath\.mbw\.tarball" -PathType Container ) ) {
      mkdir -Path "$HomePath\.mbw\.tarball" | Out-Null
    }

    if ( Test-Path -LiteralPath "$HomePath\.mbw\.tarball\$Release-$SysArchName.tar.gz" -PathType Leaf ) {

      if ( $Force ) {
        Write-Host "# WSL tarball for $Release($SysArchName) found but -Force passed. Redownloading..." -ForegroundColor DarkYellow
        $download_start_time = Get-Date
        (New-Object System.Net.WebClient).DownloadFile("http://cloud-images.ubuntu.com/$Release/current/$Release-server-cloudimg-$SysArchName-wsl.rootfs.tar.gz", "$HomePath\.mbw\.tarball\$Release-amd64.tar.gz")

        Write-Host "# Download completed for the WSL tarball for $Release($SysArchName). Time taken: $((Get-Date).Subtract($download_start_time).Seconds) second(s)" -ForegroundColor DarkYellow
      }
      else {
        Write-Host "# WSL tarball for $Release ($SysArchName) found, skip downloading" -ForegroundColor DarkYellow
      }

    }
    else {

      Write-Host "# WSL tarball for $Release ($SysArchName) not found. Downloading..." -ForegroundColor DarkYellow
      $download_start_time = Get-Date
      (New-Object System.Net.WebClient).DownloadFile("http://cloud-images.ubuntu.com/$Release/current/$Release-server-cloudimg-$SysArchName-wsl.rootfs.tar.gz", "$HomePath\.mbw\.tarball\$Release-amd64.tar.gz")

      Write-Host "# Download completed for the WSL tarball for $Release($SysArchName). Time taken: $((Get-Date).Subtract($download_start_time).Seconds) second(s)" -ForegroundColor DarkYellow

    }

    # get absolute unique TmpName
    Do {
      $tmpname_exist = $false
      foreach ($i in $inst_list) {
        if ($i.ID -eq "$TmpName") { $tmpname_exist = $true }
      }
      if ( $tmpname_exist -eq $true ) { $TmpName = -join ((65..90) + (97..122) | Get-Random -Count 10 | ForEach-Object { [char]$_ }) }
    } until ($tmpname_exist -eq $false)

    Write-Host "# Creating instance ubuntu-$TmpName (Using Ubuntu $Release and WSL$Version)...." -ForegroundColor DarkYellow
    wsl.exe --import ubuntu-$TmpName "$HomePath\.mbw\ubuntu-$TmpName" "$HomePath\.mbw\.tarball\$Release-amd64.tar.gz" --version $Version

    if ($EnableSource) {
      Write-Host "# Enabling Ubuntu source repository...." -ForegroundColor DarkYellow
      Write-Host "# -NoUpdate will be ignored if passed" -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$TmpName sed -i `"s`|`# deb-src`|deb-src`|g`" /etc/apt/sources.list
    }

    if ($EnableProposed) {
      Write-Host "# Enabling Ubuntu Proposed repository...." -ForegroundColor DarkYellow
      Write-Host "# -NoUpdate will be ignored if passed" -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$TmpName echo -e `"`# Enable Ubuntu proposed archive\ndeb http`://archive.ubuntu.com/ubuntu/ `$`(lsb_release `-cs`)-proposed restricted main multiverse universe`" `> /etc/apt/sources.list.d/ubuntu-`$`(lsb_release `-cs`)-proposed.list
      if ( $SysArchName -eq "arm64" ) {
        wsl.exe -d ubuntu-$TmpName echo -e `"`# Enable Ubuntu proposed archive\ndeb http`://ports.ubuntu.com/ubuntu-ports `$`(lsb_release `-cs`)-proposed restricted main multiverse universe`" `> /etc/apt/sources.list.d/ubuntu-`$`(lsb_release `-cs`)-proposed.list
      }
      if (-not $DisableSelective) {
        wsl.exe -d ubuntu-$TmpName echo -e `"`# Configure apt to allow selective installs of packages `from proposed\nPackage: `*\nPin`: release a`=`$`(lsb_release `-cs`)-proposed\nPin-Priority`: 400`" `>`> /etc/apt/preferences.d/proposed-updates
      }
    }

    if ( -not $NoUpdate -or ($EnableSource -or $EnableProposed) ) {
      Write-Host "# Updating ubuntu-$TmpName...." -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$TmpName apt update
      wsl.exe -d ubuntu-$TmpName apt upgrade -y
    }

    if ( -not $RootOnly ) {
      Write-Host "# Creating user '$env:USERNAME' for ubuntu-$TmpName...." -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$TmpName /usr/sbin/useradd -m -s "/bin/bash" $env:USERNAME
      wsl.exe -d ubuntu-$TmpName passwd -q -d $env:USERNAME
      wsl.exe -d ubuntu-$TmpName echo `"$env:USERNAME ALL=`(ALL`:ALL`) NOPASSWD: ALL`" `| tee -a /etc/sudoers.d/$env:USERNAME `>/dev/null
      wsl.exe -d ubuntu-$TmpName /usr/sbin/usermod -a -G adm,dialout,cdrom,floppy,sudo,audio,dip,video,plugdev,netdev $env:USERNAME
    }

    if ($AdditionalPPA) {
      $ppa_array = $AdditionalPPA -split ","

      foreach ($appa in $ppa_array) {
        Write-Host "# Adding additional PPA '$appa'...." -ForegroundColor DarkYellow
        wsl.exe -d ubuntu-$TmpName /usr/bin/apt-add-repository -y "ppa:$appa"
        wsl.exe -d ubuntu-$TmpName apt update
        wsl.exe -d ubuntu-$TmpName apt upgrade -y
      }
    }

    Write-Host "# You are ready to rock!" -ForegroundColor DarkYellow
    if ( -not $RootOnly ) {
      wsl.exe -d ubuntu-$TmpName -u $env:USERNAME
    }
    else {
      wsl.exe -d ubuntu-$TmpName -u root
    }
  }
}

function Remove-UbuntuWSLInstance {
  <#
    .SYNOPSIS
        Remove an Ubuntu instance on WSL
    .DESCRIPTION
        Remove an Ubuntu instance on WSL
    .PARAMETER Id
        The ID of the instance, after the name of distro "ubuntu-".
    .EXAMPLE
        Remove-UbuntuWSLInstance -Id AbcdEFGhiJ
        # Remove an instance called ubuntu-AbcdEFGhiJ
    .LINK
        https://github.com/patrick330602/PsUWI
    #>
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory = $true)]
    [string]$Id
  )
  Process {
    $HomePath = $env:HOME
    if (-not $HomePath) {
      $HomePath = "$($env:HOMEDRIVE)$($env:HOMEPATH)"
    }

    if ( -not ( Get-ChildItem "$HomePath\.mbw" | Select-String "$Id" ) ) {
      throw [System.IO.FileNotFoundException] "$Id not found."
    }

    Write-Host "# Removing instance ubuntu-$Id..." -ForegroundColor DarkYellow

    Write-Host "# Terminating instance ubuntu-$Id..." -ForegroundColor DarkYellow
    wsl.exe -t ubuntu-$Id
    Write-Host "# Unregistering instance ubuntu-$Id..." -ForegroundColor DarkYellow
    wsl.exe --unregister ubuntu-$Id
    Write-Host "# Cleanup..." -ForegroundColor DarkYellow
    Remove-Item "$HomePath\.mbw\ubuntu-$Id" -Force -Recurse

    Write-Host "# Removed instance ubuntu-$Id." -ForegroundColor DarkYellow
  }
}

function Remove-AllUbuntuWSLInstances {
  <#
    .SYNOPSIS
        Remove all Ubuntu instances on WSL
    .DESCRIPTION
        Remove all Ubuntu instances on WSL
    .EXAMPLE
        Remove-AllUbuntuWSLInstances
        # Remove all instances
    .LINK
        https://github.com/patrick330602/PsUWI
    #>
  $HomePath = $env:HOME
  if (-not $HomePath) {
    $HomePath = "$($env:HOMEDRIVE)$($env:HOMEPATH)"
  }
  
  Write-Host "# Removing all instances..." -ForegroundColor DarkYellow
  $UbuntuDistroList = @(Get-ChildItem "$HomePath\.mbw" -Filter ubuntu-*)
  Foreach ($i in $UbuntuDistroList) {
    Remove-UbuntuWSLInstance -Id ($i.BaseName).split('-')[1]
  }
  Write-Host "# Removed all instances." -ForegroundColor DarkYellow
}
