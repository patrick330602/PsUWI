function New-UbuntuWSLInstance {
    <#
    .SYNOPSIS
        Create an new Ubuntu instance on WSL
    .DESCRIPTION
        Create an new Ubuntu instance on WSL. Windows 10 2004 only for now.
    .PARAMETER Release
        The Ubuntu relase you want to use to create the instance. Default is focal.
    .PARAMETER Version
        The WSL version you want to use. Default is 1.
    .PARAMETER Force
        If specified, an new WSL tarball will always be downloaded even if it exists.
    .PARAMETER NoUpdate
        If specified, it will not update during the creation.
    .PARAMETER RootOnly
        If specified, no new user will be created.
    .EXAMPLE
        New-UbuntuWSLInstance -Release bionic
        # Create a Ubuntu Bionic instance on WSL1
    .EXAMPLE
        New-UbuntuWSLInstance -Release xenial -Version 2 -RootOnly
        # Create a Ubuntu Xenial instance on WSL2 without creating a user account
    .EXAMPLE
        New-UbuntuWSLInstance -Version 2 -NoUpdate
        # Create a Ubuntu Focal instance on WSL2 witout any update
    .EXAMPLE
        New-UbuntuWSLInstance -Release eoan -Force
        # Create a Ubuntu Eoan instance on WSL1 and download the WSL tarball even it already exists
    .LINK
        https://github.com/patrick330602/PsUWI
    #>
    [cmdletbinding()]
    Param (
      [Parameter(Mandatory=$false)]
      [string]$Release = 'focal',
      [Parameter(Mandatory=$false)]
      [ValidateSet('1','2')]
      [string]$Version = '1',
      [Parameter(Mandatory=$false)]
      [Switch]
      [boolean]$Force,
      [Parameter(Mandatory=$false)]
      [Switch]
      [boolean]$NoUpdate,
      [Parameter(Mandatory=$false)]
      [Alias("Root")]
      [Switch]
      [boolean]$RootOnly
    )
    Process {
      Write-Host "# Let the journey begin!" -ForegroundColor DarkYellow

      $TmpName = -join ((65..90) + (97..122) | Get-Random -Count 10 | ForEach-Object {[char]$_})

      $SysArchName = ($env:PROCESSOR_ARCHITECTURE).ToLower()
      if ( -not ( ( $SysArchName -eq "amd64" ) -or ( $SysArchName -eq "arm64" ) ) ) {
        throw [System.NotSupportedException] "The architecture $SysArchName is not supported."
      }
      if ( ( $Release -eq "xenial" ) -and ( $SysArchName -eq "arm64" ) ) {
        throw [System.NotSupportedException] "Ubuntu Xenial do not support architecture arm64."
      }
      Write-Host "# Your system architecture is $SysArchName" -ForegroundColor DarkYellow

      if ( -not (Test-Path -Path "$env:HOME\.mbw" -PathType Container ) ) {
        mkdir -Path "$env:HOME\.mbw" | Out-Null
      }

      if ( -not (Test-Path -Path "$env:HOME\.mbw\.tarball" -PathType Container ) ) {
        mkdir -Path "$env:HOME\.mbw\.tarball" | Out-Null
      }

      if ( Test-Path -LiteralPath "$env:HOME\.mbw\.tarball\$Release-$SysArchName.tar.gz" -PathType Leaf ) {

        if ( $Force ) {
            Write-Host "# WSL tarball for $Release($SysArchName) found but -Force passed. Redownloading..." -ForegroundColor DarkYellow
            $download_start_time = Get-Date
            (New-Object System.Net.WebClient).DownloadFile("http://cloud-images.ubuntu.com/$Release/current/$Release-server-cloudimg-$SysArchName-wsl.rootfs.tar.gz", "$env:HOME\.mbw\.tarball\$Release-amd64.tar.gz")

            Write-Host "# Download completed for theWSL tarball for $Release($SysArchName). Time taken: $((Get-Date).Subtract($download_start_time).Seconds) second(s)" -ForegroundColor DarkYellow
        } else {
            Write-Host "# WSL tarball for $Release ($SysArchName) found, skip downloading" -ForegroundColor DarkYellow
        }

      } else {

        Write-Host "# WSL tarball for $Release ($SysArchName) not found. Downloading..." -ForegroundColor DarkYellow
        $download_start_time = Get-Date
        (New-Object System.Net.WebClient).DownloadFile("http://cloud-images.ubuntu.com/$Release/current/$Release-server-cloudimg-$SysArchName-wsl.rootfs.tar.gz", "$env:HOME\.mbw\.tarball\$Release-amd64.tar.gz")

        Write-Host "# Download completed for theWSL tarball for $Release($SysArchName). Time taken: $((Get-Date).Subtract($download_start_time).Seconds) second(s)" -ForegroundColor DarkYellow

      }

      if ( -not ( Test-Path -LiteralPath "$env:HOME\.mbw\list.csv" -PathType Leaf ) ) {
        Add-Content "$env:HOME\.mbw\list.csv" "ID,Release,Version"
      }

      $inst_list = Import-Csv "$env:HOME\.mbw\list.csv"

      # get absolute unique TmpName
      Do {
        $tmpname_exist = $false
        foreach ($i in $inst_list) {
          if ($i.ID -eq "$TmpName") { $tmpname_exist = $true }
        }
        if ( $tmpname_exist -eq $true ) { $TmpName = -join ((65..90) + (97..122) | Get-Random -Count 10 | ForEach-Object {[char]$_}) }
      } until ($tmpname_exist -eq $false)

      Write-Host "# Creating Instance ubuntu-$TmpName (Using Ubuntu $Release and WSL$Version)...." -ForegroundColor DarkYellow
      wsl.exe --import ubuntu-$TmpName "$env:HOME\.mbw\ubuntu-$TmpName" "$env:HOME\.mbw\.tarball\$Release-amd64.tar.gz" --version $Version

      if ( -not $NoUpdate ) {
        Write-Host "# Updating ubuntu-$TmpName...." -ForegroundColor DarkYellow
        wsl.exe -d ubuntu-$TmpName apt update
        wsl.exe -d ubuntu-$TmpName apt upgrade -y
      }

      if ( -not $RootOnly ) {
        Write-Host "# Creating user '$env:USERNAME' for ubuntu-$TmpName...." -ForegroundColor DarkYellow
        wsl.exe -d ubuntu-$TmpName /usr/sbin/useradd -m -s "/bin/bash" $env:USERNAME
        wsl.exe -d ubuntu-$TmpName passwd -q -d $env:USERNAME
        wsl.exe -d ubuntu-$TmpName /usr/sbin/usermod -aG adm,dialout,cdrom,floppy,sudo,audio,dip,video,plugdev,netdev $env:USERNAME
      }

      Write-Host "# You are ready to rock!" -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$TmpName -u $env:USERNAME
    }
  }

  function Remove-UbuntuWSLInstance {
    <#
    .SYNOPSIS
        Remove a Ubuntu instance on WSL
    .DESCRIPTION
        Remove a Ubuntu instance on WSL
    .PARAMETER Id
        The id of the instance, after the name of distro "ubuntu-".
    .EXAMPLE
        Remove-UbuntuWSLInstance -Id AbcdEFGhiJ
        # Remove a instance called ubuntu-AbcdEFGhiJ
    .LINK
        https://github.com/patrick330602/PsUWI
    #>
    [cmdletbinding()]
    Param (
      [Parameter(Mandatory=$true)]
      [string]$Id
    )
    Process {
      if ( -not ( Get-ChildItem "$env:HOME\.mbw" | Select-String "$Id" ) ) {
        throw [System.IO.FileNotFoundException] "$Id not found."
      }

      Write-Host "# Removing Instance ubuntu-$Id..." -ForegroundColor DarkYellow

      Write-Host "# Terminating Instance ubuntu-$Id..." -ForegroundColor DarkYellow
      wsl.exe -t ubuntu-$Id
      Write-Host "# Unregistering Instance ubuntu-$Id..." -ForegroundColor DarkYellow
      wsl.exe --unregister ubuntu-$Id
      Write-Host "# Cleanup..." -ForegroundColor DarkYellow
      Remove-Item "$env:HOME\.mbw\ubuntu-$Id" -Force -Recurse

      Write-Host "# Removed Instance ubuntu-$Id." -ForegroundColor DarkYellow
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
    Write-Host "# Removing all instances..." -ForegroundColor DarkYellow
    $UbuntuDistroList = @(Get-ChildItem "$env:HOME\.mbw" -Filter ubuntu-*)
    Foreach ($i in $UbuntuDistroList) {
      Remove-UbuntuWSLInstance -Id ($i.BaseName).split('-')[1]
    }
    Write-Host "# Removed all instances." -ForegroundColor DarkYellow
  }