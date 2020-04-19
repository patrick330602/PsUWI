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
        throw [System.NotSupportedException] "The Architecture $SysArchName is not supported."
      }
      Write-Host "## Architecture: $SysArchName" -ForegroundColor DarkYellow

      if ( -not (Test-Path -Path "$env:HOME\ubuntu-wslinstance" -PathType Container ) ) {
        mkdir -Path "$env:HOME\ubuntu-wslinstance" | Out-Null
      }

      if ( -not (Test-Path -Path "$env:HOME\ubuntu-wslinstance\.tarball" -PathType Container ) ) {
        mkdir -Path "$env:HOME\ubuntu-wslinstance\.tarball" | Out-Null
      }

      if ( Test-Path -LiteralPath "$env:HOME\ubuntu-wslinstance\.tarball\$ReleaseName-$SysArchName.tar.gz" -PathType Leaf ) {
          
        if ( $Force ) {
            Write-Host "# WSL tarball for $ReleaseName($SysArchName) found but -Force passed. Redownloading..." -ForegroundColor DarkYellow
            $download_start_time = Get-Date
            (New-Object System.Net.WebClient).DownloadFile("http://cloud-images.ubuntu.com/$ReleaseName/current/$ReleaseName-server-cloudimg-$SysArchName-wsl.rootfs.tar.gz", "$env:HOME\ubuntu-wslinstance\$ReleaseName-amd64.tar.gz")

            Write-Host "# Download completed for theWSL tarball for $ReleaseName($SysArchName). Time taken: $((Get-Date).Subtract($download_start_time).Seconds) second(s)" -ForegroundColor DarkYellow
        } else {
            Write-Host "# WSL tarball for $ReleaseName($SysArchName) found, skip downloading" -ForegroundColor DarkYellow
        }

      } else {

        Write-Host "# WSL tarball for $ReleaseName($SysArchName) not found. Downloading..." -ForegroundColor DarkYellow
        $download_start_time = Get-Date
        (New-Object System.Net.WebClient).DownloadFile("http://cloud-images.ubuntu.com/$ReleaseName/current/$ReleaseName-server-cloudimg-$SysArchName-wsl.rootfs.tar.gz", "$env:HOME\ubuntu-wslinstance\$ReleaseName-amd64.tar.gz")

        Write-Host "# Download completed for theWSL tarball for $ReleaseName($SysArchName). Time taken: $((Get-Date).Subtract($download_start_time).Seconds) second(s)" -ForegroundColor DarkYellow
        
      }

      Write-Host "# Creating Instance ubuntu-$ReleaseName-$TmpName (Using WSL$Version)...." -ForegroundColor DarkYellow
      wsl.exe --import ubuntu-$ReleaseName-$TmpName "$env:HOME\ubuntu-wslinstance\ubuntu-$ReleaseName-$TmpName" "$env:HOME\ubuntu-wslinstance\.tarball\$ReleaseName-amd64.tar.gz" --version $Version
      Write-Host "# Updating ubuntu-$ReleaseName-$TmpName...." -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$ReleaseName-$TmpName apt update
      wsl.exe -d ubuntu-$ReleaseName-$TmpName apt upgrade -y
      Write-Host "# Creating user '$env:USERNAME' for ubuntu-$ReleaseName-$TmpName...." -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$ReleaseName-$TmpName /usr/sbin/useradd -m -s "/bin/bash" $env:USERNAME
      wsl.exe -d ubuntu-$ReleaseName-$TmpName passwd -q -d $env:USERNAME
      wsl.exe -d ubuntu-$ReleaseName-$TmpName /usr/sbin/usermod -aG adm,dialout,cdrom,floppy,sudo,audio,dip,video,plugdev,netdev $env:USERNAME
      Write-Host "# You are ready to rock!" -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$ReleaseName-$TmpName -u $env:USERNAME
    }
  }

  function Remove-UbuntuWSLInstance {
    [cmdletbinding()]
    Param (
      [Parameter(Mandatory=$true)]
      [string]$Name
    )
    Process {
      if ( -not ( Get-ChildItem "$env:HOME\ubuntu-wslinstance" | Select-String "$Name" ) ) {
        throw [System.IO.FileNotFoundException] "$Name not found."
      }
      Write-Host "# Removing Instance $Name...." -ForegroundColor DarkYellow
      wsl.exe -t $Name
      wsl.exe --unregister $Name
      Remove-Item "$env:HOME\ubuntu-wslinstance\$Name" -Force -Recurse
      Write-Host "# Removed Instance $Name." -ForegroundColor DarkYellow
    }
  }

  function Remove-AllUbuntuWSLInstances {
    Write-Host "# Removing all instances..." -ForegroundColor DarkYellow
    $UbuntuDistroList = @(Get-ChildItem "$env:HOME\ubuntu-wslinstance" | Select-String ^ubuntu-)
    Foreach ($i in $UbuntuDistroList) {
      Remove-UbuntuWSLInstance -Name $i
    }
    Write-Host "# Removed all instances." -ForegroundColor DarkYellow
  }