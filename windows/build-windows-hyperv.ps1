function Get-RunningMessage($startDate) {
    $currentDate = Get-Date
    $difference = $currentDate - $startDate
    $hours = $difference.Hours
    $minutes = $difference.Minutes
    $seconds = $difference.Seconds
    $message = "Process has been running for "
    if ($hours -gt 0) {
        $message = $message + "$hours hours, "
    }
    $message = $message + "$minutes minutes, $seconds seconds."
    return $message
}

$ErrorActionPreference = "Stop"
$imageName = "Windows-2016-1709-With-Containers"
$vmS3Path = "s3://windows-1709/windows-1709-hyperv-vm.vhdx"
$keyName = "jvb"
$instanceType = "t2.medium"
$regions = "us-east-1", "us-east-2", "us-west-1", "us-west-2"
$sourceRegion = aws configure get region
$username = "Packer"
$password = "Packer" | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username,$password)

$ErrorActionPreference

$startDate = Get-Date
Write-Host "Starting AMI Creation Process at $startDate."

Write-Host "Creating Hyper-v Image with Packer."
packer build -force -var-file windows_server_1709_with_containers.json build-windows-1709-hyper-image.json

Write-Host "$(Get-RunningMessage $startDate)."

Write-Host "Checking for existing AMI, $imageName."
$ami = aws ec2 describe-images --filters "Name=name,Values=$imageName" | ConvertFrom-Json | Select-Object -ExpandProperty Images

Write-Host "Checking for existing Hyper-V Virtual Machine on S3 at $vmS3Path."
$hdxCount = (aws s3 ls $vmS3Path --output json | Measure-Object ).Count

if ($hdxCount -ne 0) {
    aws s3 rm $vmS3Path
}
else {
    "No Hyper-V Virtual Machine found on S3 at $vmS3Path."
}

Write-Host "$(Get-RunningMessage $startDate)."

Write-Host "Uploading VM to $vmS3Path."
aws s3 cp "./output-hyperv-iso/Virtual Hard Disks/WindowsServer1709.vhdx" "$vmS3Path"

Write-Host "$(Get-RunningMessage $startDate)."

Write-Host "Register VM as AMI"
$task = aws ec2 import-image --license-type BYOL --disk-containers file://containers.json | ConvertFrom-Json

$taskId = $task.ImportTaskId

Write-Host "Monitoring Import Task Until it's completed."

$task = (aws ec2 describe-import-image-tasks --import-task-ids $taskId | ConvertFrom-Json).ImportImageTasks

while ($task.Status -eq "active") {
    $task = (aws ec2 describe-import-image-tasks --import-task-ids $taskId | ConvertFrom-Json).ImportImageTasks    
    $message = Get-RunningMessage $startDate
    $percentComplete = $task.Progress
    if ($percentComplete -eq $null) {
        $percentComplete = 0
    }
    Write-Progress -Activity "AMI is currently $($task.StatusMessage)." -Status $message -PercentComplete $percentComplete
    Start-Sleep 10
}

Write-Progress -Activity "AMI Processing Finished." -Completed

Write-Host "$(Get-RunningMessage $startDate)."

"Image Id: $($task.ImageId)."

$imageId = $($task.ImageId)

Write-Host "Creating an Instance from the AMI image."

$instances = aws ec2 run-instances --image-id $task.ImageId --key-name $keyName --instance-type $instanceType --security-groups all-open | ConvertFrom-Json

Write-Host "Waiting 5 minutes for DNS and Public IPs"

Start-Sleep -Seconds 300

Write-Host "$(Get-RunningMessage $startDate)."

Write-Host "Adding instance to trusted hosts"

$instanceIds = ""
foreach($instance in $instances.Instances) {
        $instanceIds += ($instance.InstanceId + ",")
}

$instanceIds = $instanceIds.Substring(0, $instanceIds.Length - 1)

$instance = (aws ec2 describe-instances --instance-ids $instanceIds | ConvertFrom-Json).Reservations[0].Instances

aws ec2 create-tags --resources $instance.InstanceId --tags Key=name,Value=1709-test

Set-Item "WSMan:\localhost\Client\TrustedHosts" -Value "$($instance.PublicDnsName)" -Force

Write-Host "Allowing Unencrypted WinRM Connections"

Set-Item "WSMan:\localhost\Client\AllowUnencrypted" -Value "true" -Force

Write-Host "$(Get-RunningMessage $startDate)."

Write-Host "Schedule initialization and run sysprep"

Enter-PSSession -ComputerName $instance.PublicDnsName -Credential $credential

C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts\InitializeInstance.ps1 -Schedule; C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts\SysprepInstance.ps1 -ErrorAction Continue

Exit-PSSession -ErrorAction Continue

Write-Host "$(Get-RunningMessage $startDate)."

Write-Host "Creating Image from Sysprepped machine."

$imageId = aws ec2 create-image --instance-id $instance.InstanceId --name "Windows Server 2016 1709 With Containers" --no-reboot

Write-Host "Propogate Image to other regions."

foreach($region in $regions) {
    if($region -eq $sourceRegion) {
        Write-Host "Skipping source region $sourceRegion."
    } else {
        Write-Host "Copying image to $region."
        aws ec2 copy-image --source-region $sourceRegion  source-image-id  $imageId  --name "Windows Server 2016 1709 With Containers"     
    }
}

Write-Host "Done."

$endDate = Get-Date
$difference = $endDate - $startDate

Write-Host "AMI Process Complete. $($difference.Hours) hours, $($difference.Minutes) minutes, and $($difference.Seconds) seconds."