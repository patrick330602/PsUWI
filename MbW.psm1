function Start-UbuntuWSLInstance {

}

function New-UbuntuWSLInstance {
    [cmdletbinding()]
    Param (
      [Parameter(Mandatory=$false)]
      [string]$Name,
      [Parameter(Mandatory=$false)]
      [string]$DistroName = 'focal',
      [Parameter(Mandatory=$false)]
      [ValidateSet('1','2')]
      [string]$Version = '1',
      [Parameter(Mandatory=$false)]
      [Switch]
      [boolean]$Force
    )
    Process {
      $TmpName = -join ((65..90) + (97..122) | Get-Random -Count 10 | ForEach-Object {[char]$_})

      if ( -not (Test-Path -Path "$env:HOME\ubuntu-wslinstance" -PathType Container ) ) {
        mkdir -Path "$env:HOME\ubuntu-wslinstance" | Out-Null
      }

      if ( -not (Test-Path -Path "$env:HOME\ubuntu-wslinstance\.tarball" -PathType Container ) ) {
        mkdir -Path "$env:HOME\ubuntu-wslinstance\.tarball" | Out-Null
      }

      if ( Test-Path -LiteralPath "$env:HOME\ubuntu-wslinstance\.tarball\$DistroName-amd64.tar.gz" -PathType Leaf ) {
        if ( $Force ) {
            Write-Host "# $DistroName-amd64.tar.gz found but -Force passed. Redownloading..." -ForegroundColor DarkYellow
            $download_start_time = Get-Date
            (New-Object System.Net.WebClient).DownloadFile("http://cloud-images.ubuntu.com/$DistroName/current/$DistroName-server-cloudimg-amd64-wsl.rootfs.tar.gz", "$env:HOME\ubuntu-wslinstance\$DistroName-amd64.tar.gz")

            Write-Host "# Download completed for $DistroName-amd64.tar.gz. Time taken: $((Get-Date).Subtract($download_start_time).Seconds) second(s)" -ForegroundColor DarkYellow
        } else {
            Write-Host "# $DistroName-amd64.tar.gz found, skip downloading" -ForegroundColor DarkYellow
        }
      } else {
        Write-Host "# $DistroName-amd64.tar.gz not found. Downloading..." -ForegroundColor DarkYellow
        $download_start_time = Get-Date
        (New-Object System.Net.WebClient).DownloadFile("http://cloud-images.ubuntu.com/$DistroName/current/$DistroName-server-cloudimg-amd64-wsl.rootfs.tar.gz", "$env:HOME\ubuntu-wslinstance\$DistroName-amd64.tar.gz")

        Write-Host "# Download completed for $DistroName-amd64.tar.gz. Time taken: $((Get-Date).Subtract($download_start_time).Seconds) second(s)" -ForegroundColor DarkYellow
      }

      Write-Host "# Creating Instance ubuntu-$DistroName-$TmpName (Using WSL$Version)...." -ForegroundColor DarkYellow
      wsl.exe --import ubuntu-$DistroName-$TmpName "$env:HOME\ubuntu-wslinstance\ubuntu-$DistroName-$TmpName" "$env:HOME\ubuntu-wslinstance\.tarball\$DistroName-amd64.tar.gz" --version $Version
      Write-Host "# Updating ubuntu-$DistroName-$TmpName...." -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$DistroName-$TmpName apt update
      wsl.exe -d ubuntu-$DistroName-$TmpName apt upgrade -y
      Write-Host "# Creating user '$env:USERNAME' for ubuntu-$DistroName-$TmpName...." -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$DistroName-$TmpName /usr/sbin/useradd -m -s "/bin/bash" $env:USERNAME
      wsl.exe -d ubuntu-$DistroName-$TmpName passwd -q -d $env:USERNAME
      wsl.exe -d ubuntu-$DistroName-$TmpName /usr/sbin/usermod -aG adm,dialout,cdrom,floppy,sudo,audio,dip,video,plugdev,netdev $env:USERNAME
      Write-Host "# You are ready to rock!" -ForegroundColor DarkYellow
      wsl.exe -d ubuntu-$DistroName-$TmpName -u $env:USERNAME
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