# PsUbuntuWSLInstance

![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/PsUWI) ![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PsUWI)

This is A PowerShell helper to create testing Ubuntu instances on WSL.

Install using `Install-Module -Name PsUWI` and import the Module using `Import-Module PsUWI`

Here are some example uses:
```powershell
New-UbuntuWSLInstance -Release bionic
# Create a Ubuntu Bionic instance on WSL1

New-UbuntuWSLInstance -Release xenial -Version 2 -RootOnly
# Create an Ubuntu Xenial instance on WSL2 without creating a user account

New-UbuntuWSLInstance -Version 2 -NoUpdate
# Create an Ubuntu Focal instance on WSL2 without any update

New-UbuntuWSLInstance -Release eoan -Force
# Create an Ubuntu Eoan instance on WSL1 and download the WSL tarball even if it already exists

Remove-UbuntuWSLInstance -Id AbcdEFGhiJ
# Remove an instance called ubuntu-AbcdEFGhiJ

Remove-AllUbuntuWSLInstances
# Remove all instances
```

# License

MIT.
