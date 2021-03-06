# Create a Custom Windows 1709 AWS AMI with Packer

The contents of this folder is to build Windows Server 2016 Hyper-v Virtual Machines and use them to build Windows AMIs for Amazon EC2.

## Warning

This repository is a work in process.  The parts after the registration of the AMI are broken and I'll be fixing them soon.  Use at your own risk.

### TODO

- [ ] Remotely execute sysprep and EC2Launch initialization.
- [ ] Cleanup non-sysprepped AMIs
- [ ] Lock down and properly secure instances for production.

## Prerequisites

* Windows Operating System with Hyper-V enabled.
* Packer installed and available via your user or system PATH variable.
* A property configured aws cli.
* en_windows_server_version_1709_updated_jan_2018_x64_dvd_100492040.iso in this directory or another iso and an updated variables file.
* Roles and Policies within AWS to create s3 buckets and register AMI files.

The installation examples are using the [Chocolatey package manager](https://chocolatey.org/).

### Install Packer

`choco install packer -y`

### Install AWS CLI

`choco install awscli -y`

### Configure your AWS account

`aws configure`

### Create an S3 bucket for image imports

`aws s3api create-bucket --bucket windows-1709 --region us-east-1`

### Create a 'vmimport' IAM role and policy

* Create a file with this policy called trust-policy.json

```json

{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
            "StringEquals":{
               "sts:Externalid": "vmimport"
            }
         }
      }
   ]
}

```

* Create a the role

`aws iam create-role --role-name vmimport --assume-role-policy-document file://trust-policy.json`

* Create a file named role-policy.json with the following policy, where disk-image-file-bucket is the bucket you created.

```json

{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Action":[
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket" 
         ],
         "Resource":[
            "arn:aws:s3:::disk-image-file-bucket",
            "arn:aws:s3:::disk-image-file-bucket/*"
         ]
      },
      {
         "Effect":"Allow",
         "Action":[
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource":"*"
      }
   ]
}

```

In the trust-policy file include in this repository, the resource is as follows.

```json
"Resource":[
             "arn:aws:s3:::windows-1709",
             "arn:aws:s3:::windows-1709/*"
          ]
```

* Use the put-role-policy command to apply the policy you created to `vmimport` role

`aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document file://role-policy.json`

## How does this work?

Run `build-windows-hyperv.ps1`

First this will

* use packer to build a hyper-v iso with Windows 2016 installed.
  * disable the screensaver
  * run any microsoft updates
  * run any windows updates
  * turn off the Windows Server firewall and enable WinRM.
  * enable RDP
  * Install Amazon EC2Launch

The output of this part of the script will be a folder called output-hyperv-iso, which will have the Windows Virtual Machine and Virtual Hard Disks.

At this point the `build-windows-hyperv.ps1` script will

* Check and delete any existing Hyper-V Virtual Machine with the s3 Path of the `$vmS3PathS` variable at the top of the script.
* Upload the Hyper-V vm generated by packer. This takes a while.
* Register the Virtual Machine as a Windows AMI in EC2.  This also takes a while.

Until the process has ended in error or completed, the `build-windows-hyperv.ps1` script will monitor the import task.

After the VM is imported, this `build-windows-hyperv.ps1` script will

* Create an instance of the AMI.
* Run EC2Launch to schedule initialization and sysprep the machine.
* Create an AMI from the sysprepped image

## A note about security.

This setup is not meant for production system.  The WinRM is currently setup to be used in an unencrypted manner.

To connect via `Enter-PSSession` you must trust the remote hoste and allow unencrypted connections using Basic Auth

`Set-item "WsMan:\localhost\Client\Trustedhosts" -Value '<fqdn or ip>,<fqdn or ip>' -Force`
`Set-Item "WSMan:\localhost\Client\AllowUnencrypted" -Value true`
