$ErrorActionPreference = "Stop"
$imageName = "Windows-2016-1709-With-Containers"
$vmS3Path = "s3://windows-1709/windows-1709-hyperv-vm.vhdx"

$startDate = Get-Date
Write-Host "Starting AMI Creation Process at $startDate."

Write-Host "Creating Hyper-v Image with Packer."
packer build -force -var-file windows_server_1709_with_containers.json build-windows-1709-hyper-image.json

Write-Host "Checking for existing AMI, $imageName."
$ami = aws ec2 describe-images --filters Name=name,Values=$imageName | ConvertFrom-Json | Select-Object -ExpandProperty Images

Write-Host "Checking for existing Hyper-V Virtual Machine on S3 at $vmS3Path."
$hdxCount = (aws s3 ls $vmS3Path --output json | Measure-Object ).Count

if($ami -ne $null) {
    aws ec2 deregister-image --image-id $ami.ImageId
} else {
    "No AMI found with name $imageName."
}

if($hdxCount -ne 0) {
    aws s3 rm $vmS3Path
} else {
    "No Hyper-V Virtual Machine found on S3 at $vmS3Path."
}

Write-Host "Uploading VM to $vmS3Path."
aws s3 cp "./output-hyperv-iso/Virtual Hard Disks/WindowsServer1709.vhdx" "$vmS3Path"

Write-Host "Register VM as AMI"
$task = aws ec2 import-image --license-type BYOL --disk-containers file://containers.json | ConvertFrom-Json

$taskId = $task.ImportTaskId

Write-Host "Monitor Import Task Until it's completed."

$task =  (aws ec2 describe-import-image-tasks --import-task-ids $taskId | ConvertFrom-Json).ImportImageTasks

while($task.Status -eq "active") {
    $task =  (aws ec2 describe-import-image-tasks --import-task-ids $taskId | ConvertFrom-Json).ImportImageTasks    
    $currentDate = Get-Date
    $difference = $currentDate - $startDate
    Write-Host "Import Task Update: AMI is currently $($task.StatusMessage). Progress: $($task.Progress)%.  Will check again shortly.  Process has been running for $($difference.TotalMinutes) minutes."
    Start-Sleep -Seconds $(Get-Random -Minimum 45 -Maximum 180)
}

Write-Host "Import is done.  AMI has either ended in error or is ready for testing."
$task | Format-Wide -AutoSize

$endDate = Get-Date
$difference = $endDate - $startDate

Write-Host "AMI Process Complete. $($difference.Hours) hours, $($difference.Minutes) minutes, and $($difference.Seconds) seconds."