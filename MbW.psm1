function Start-UbuntuWSLInstance {
  Param (
    [Parameter(Mandatory=$true)]
    [string]$Name
  )
  Process {
    wsl.exe -d ubuntu-$Name -u $env:USERNAME
  }
}

function Show-AllUbuntuWSLInstances {
  if ( -not ( Test-Path -LiteralPath "$env:HOME\.mbw\list.csv" -PathType Leaf ) ) {
    Add-Content "$env:HOME\.mbw\list.csv" "ID,Release,Version"
  }

  Import-Csv "$env:HOME\.mbw\list.csv" | Format-Table
}

function New-UbuntuWSLInstance {
    [cmdletbinding()]
    Param (
      [Parameter(Mandatory=$false)]
      [string]$Name,
      [Parameter(Mandatory=$false)]
      [string]$ReleaseName = 'focal',
      [Parameter(Mandatory=$false)]
      [ValidateSet('1','2')]
      [string]$Version = '1',
      [Parameter(Mandatory=$false)]
      [Switch]
      [boolean]$Force
    )
    Process {
      Write-Host "# Let the journey begin!" -ForegroundColor DarkYellow

      $TmpName = -join ((65..90) + (97..122) | Get-Random -Count 10 | ForEach-Object {[char]$_})

      $SysArchName = ($env:PROCESSOR_ARCHITECTURE).ToLower()
      if ( -not ( ( $SysArchName -eq "amd64" ) -or ( $SysArchName -eq "arm64" ) ) ) {
        throw [System.NotSupportedException] "The architecture $SysArchName is not supported."
      }
      if ( ( $ReleaseName -eq "xenial" ) -and ( $SysArchName -eq "arm64" ) ) {
        throw [System.NotSupportedException] "Ubuntu Xenial do not support architecture arm64."
      }
      Write-Host "# Your system architecture is $SysArchName" -ForegroundColor DarkYellow

      if ( -not (Test-Path -Path "$env:HOME\.mbw" -PathType Container ) ) {
        mkdir -Path "$env:HOME\.mbw" | Out-Null
      }

      if ( -not (Test-Path -Path "$env:HOME\.mbw\.tarball" -PathType Container ) ) {
        mkdir -Path "$env:HOME\.mbw\.tarball" | Out-Null
      }

      if ( Test-Path -LiteralPath "$env:HOME\.mbw\.tarball\$ReleaseName-$SysArchName.tar.gz" -PathType Leaf ) {

        if ( $Force ) {
            Write-Host "# WSL tarball for $ReleaseName($SysArchName) found but -Force passed. Redownloading..." -ForegroundColor DarkYellow
            $download_start_time = Get-Date
            (New-Object System.Net.WebClient).DownloadFile("http://cloud-images.ubuntu.com/$ReleaseName/current/$ReleaseName-server-cloudimg-$SysArchName-wsl.rootfs.tar.gz", "$env:HOME\.mbw\.tarball\$ReleaseName-amd64.tar.gz")

            Write-Host "# Download completed for theWSL tarball for $ReleaseName($SysArchName). Time taken: $((Get-Date).Subtract($download_start_time).Seconds) second(s)" -ForegroundColor DarkYellow
        } else {
            Write-Host "# WSL tarball for $ReleaseName($SysArchName) found, skip downloading" -ForegroundColor DarkYellow
        }

      } else {

        Write-Host "# WSL tarball for $ReleaseName($SysArchName) not found. Downloading..." -ForegroundColor DarkYellow
        $download_start_time = Get-Date
        (New-Object System.Net.WebClient).DownloadFile("http://cloud-images.ubuntu.com/$ReleaseName/current/$ReleaseName-server-cloudimg-$SysArchName-wsl.rootfs.tar.gz", "$env:HOME\.mbw\.tarball\$ReleaseName-amd64.tar.gz")

        Write-Host "# Download completed for theWSL tarball for $ReleaseName($SysArchName). Time taken: $((Get-Date).Subtract($download_start_time).Seconds) second(s)" -ForegroundColor DarkYellow

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

      Add-Content "$env:HOME\.mbw\list.csv" "$TmpName,$ReleaseName,$Version"

      Write-Host "# Creating Instance ubuntu-$TmpName (Using Ubuntu $ReleaseName and WSL$Version)...." -ForegroundColor DarkYellow
      wsl.exe --import ubuntu-$TmpName "$env:HOME\.mbw\ubuntu-$TmpName" "$env:HOME\.mbw\.tarball\$ReleaseName-amd64.tar.gz" --version $Version
      Write-Host "# Updating ubuntu-$TmpName...." -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$TmpName apt update
      wsl.exe -d ubuntu-$TmpName apt upgrade -y
      Write-Host "# Creating user '$env:USERNAME' for ubuntu-$TmpName...." -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$TmpName /usr/sbin/useradd -m -s "/bin/bash" $env:USERNAME
      wsl.exe -d ubuntu-$TmpName passwd -q -d $env:USERNAME
      wsl.exe -d ubuntu-$TmpName /usr/sbin/usermod -aG adm,dialout,cdrom,floppy,sudo,audio,dip,video,plugdev,netdev $env:USERNAME
      Write-Host "# You are ready to rock!" -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$TmpName -u $env:USERNAME
    }
  }

  function Remove-UbuntuWSLInstance {
    [cmdletbinding()]
    Param (
      [Parameter(Mandatory=$true)]
      [string]$Name
    )
    Process {
      if ( -not ( Get-ChildItem "$env:HOME\.mbw" | Select-String "$Name" ) ) {
        throw [System.IO.FileNotFoundException] "$Name not found."
      }

      Write-Host "# Removing Instance ubuntu-$Name..." -ForegroundColor DarkYellow

      Write-Host "# Terminating Instance ubuntu-$Name..." -ForegroundColor DarkYellow
      wsl.exe -t ubuntu-$Name
      Write-Host "# Unregistering Instance ubuntu-$Name..." -ForegroundColor DarkYellow
      wsl.exe --unregister ubuntu-$Name
      Write-Host "# Cleanup..." -ForegroundColor DarkYellow
      Remove-Item "$env:HOME\.mbw\ubuntu-$Name" -Force -Recurse
      import-csv "$env:HOME\.mbw\list.csv" | Where-Object name -NE "$Name" | export-csv "$env:HOME\.mbw\list.csv" -NoTypeInformation
      if (-not ((Get-Content "$env:HOME\.mbw\list.csv" -Raw) -match '\S')) {
        Remove-Item "$env:HOME\.mbw\list.csv"
      }

      Write-Host "# Removed Instance ubuntu-$Name." -ForegroundColor DarkYellow
    }
  }

  function Remove-AllUbuntuWSLInstances {
    Write-Host "# Removing all instances..." -ForegroundColor DarkYellow
    $UbuntuDistroList = @(Get-ChildItem "$env:HOME\.mbw" -Filter ubuntu-*)
    Foreach ($i in $UbuntuDistroList) {
      Remove-UbuntuWSLInstance -Name ($i.BaseName).split('-')[1]
    }
    Write-Host "# Removed all instances." -ForegroundColor DarkYellow
  }