# Create a Custom Windows 1709 AWS AMI with Packer

## Install Packer

### Mac - Homebrew

brew install packer -y

### Windows - Chocolatey

choco install packer -y

### Linux - Download and Install

curl -O -J 'https://releases.hashicorp.com/packer/1.2.3/packer_1.2.3_linux_amd64.zip'
unzip ./packer_1.2.3_linux_amd64.zip
sudo cp ./packer /usr/local/bin/

## Install AWS CLI

### Mac - Homebrew

```sh

brew install awscli -y

```

### Windows - Chocolatey

```powershell 

choco install awscli -y

```

### Linux - Download and Install

```sh

curl -O -J 'https://s3.amazonaws.com/aws-cli/awscli-bundle.zip'
unzip ./awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws

```

### Windows Only - Install CDRTools Free Edition for mkisofs for windows

choco install cdrtfe -y

## Login to aws

```aws configure```

## Create an S3 bucket for image imports

```aws s3api create-bucket --bucket windows-1709 --region us-east-1 --create-bucket-configuration LocationConstraint=us-east-1```

## Create a 'vmimport' IAM role and policy

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

```sh

aws iam create-role --role-name vmimport --assume-role-policy-document file://trust-policy.json

```

* Create a file named role-policy.json with the following policy, where disk-image-file-bucket is the bucket you created

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

* Use the put-role-policy command to apply the policy you created to `vmimport` role

```sh

aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document file://role-policy.json

```

## Create an X509 key and certificate

## Create a base image from which the AMI will be created

### Option 1 Create a VirtualBox image with Packer's virtualbox-iso and have it output an image in ova format

### Option 2 Create a Hyper-V image with Packer's hyperv-iso and have it out an image in vmcx format

## Upload the OVA or VMCX image to the s3 bucket with the ```aws s3 cp``` command

## Register the OVA or VMCX image as an AMI using ```aws ec2 describe-import-image-task```