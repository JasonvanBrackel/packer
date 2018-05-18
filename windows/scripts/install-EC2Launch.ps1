$ErrorActionPreference = 'Stop'

$downloads = "https://s3.amazonaws.com/ec2-downloads-windows/EC2Launch/latest/EC2-Windows-Launch.zip", "https://s3.amazonaws.com/ec2-downloads-windows/EC2Launch/latest/install.ps1"
$destinationFolder = "C:\EC2\"

# Make EC2 folder for the download
if(!(Test-Path $destinationFolder)) {
    New-Item -ItemType Directory -Path $destinationFolder -Force
}

# Download the files
foreach($download in $downloads) {
    $WebResponse = Invoke-WebRequest -Uri $download -Method Head -UseBasicParsing
    Start-BitsTransfer -Source $WebResponse.BaseResponse.ResponseUri.AbsoluteUri.Replace("%20"," ") -Destination $destinationFolder
}

Set-Location $destinationFolder

# Unblock the files
foreach($file in Get-ChildItem -Path $destinationFolder) {
    Unblock-File -Path $file
}

# Install
./install.ps1

C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts\InitializeInstance.ps1 -Schedule