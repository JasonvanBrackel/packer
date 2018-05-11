Write-Host "Install Containers feature"
Install-WindowsFeature -Name Containers

if ((Get-WmiObject Win32_Processor).VirtualizationFirmwareEnabled[0] -and (Get-WmiObject Win32_Processor).SecondLevelAddressTranslationExtensions[0]) {
  Write-Host "Install Hyper-V feature"
  Install-WindowsFeature -Name Hyper-V -IncludeManagementTools
} else {
  Write-Host "Skipping installation of Hyper-V feature"
}
