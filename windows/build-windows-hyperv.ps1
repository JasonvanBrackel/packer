$ErrorActionPreference = "Stop"
$imageName = "Windows-2016-1709-With-Containers"
$vmS3Path = "s3://windows-1709/windows-1709-hyperv-vm.vhdx"

Write-Host "Creating Hyper-v Image"
packer build -force -var-file windows_server_1709_with_containers.json build-windows-1709-hyper-image.json

Write-Host "Checking for existing AMI."
$ami = aws ec2 describe-images --filters Name=name,Values=$imageName | ConvertFrom-Json | Select-Object -ExpandProperty Images

Write-Host "Checking for existing vhdx."
$hdxCount = (aws s3 ls $vmS3Path --output json | Measure-Object ).Count

if($ami -ne $null) {
    aws ec2 deregister-image --image-id $ami.ImageId
} else {
    "No AMI found with name $imageName."
}

if($hdxCount -ne 0) {
    aws s3 rm $vmS3Path
} else {
    "No vhdx found with name $vmS3Path."
}

Write-Host "Uploading VM to $vmS3Path."
aws s3 cp "./output-hyperv-iso/Virtual Hard Disks/WindowsServer1709.vhdx" "$vmS3Path"

Write-Host "Register VM as AMI"
aws ec2 import-image --license-type BYOL --disk-containers file://containers.json