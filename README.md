# securitymonkey_cloudformation

Stand up an AWS CloudFormation stack running [SecurityMonkey](https://github.com/Netflix/security_monkey)

This CloudFormation stack creates an AutoScaling Group guaranteeing a single EC2 instance, running SecurityMonkey and storing data in an RDS db. Both the EC2 instance and RDS db are configured with security groups. Simple CloudWatch RDS monitoring is also created. All notifications and alerts from monitoring and the AutoScaling group are published to an SNS topic that will email the provided address.

## Requirements

- AWS Account
- Install and configure [aws-cli](https://github.com/aws/aws-cli#installation)
- Ruby 1.9.3, Bundler

## Stack Parameters

You must provide values for the following parameters:

- KeyName
- EmailAddress

To customize the security profile of your stack, also override the default values of:

- CidrIp
- DatabasePassword

The default value for CidrIp will only allow SSH from the public IPv4 of the host you create the stack from. If your public IPv4 changes, re-generate the stack file using:

```bash
$ ./security_monkey_stack.rb expand > security_monkey.json
```

And run a stack update:

```bash
$ aws cloudformation update-stack --stack-name security-monkey-stack \
   --template-body file://security_monkey.json
```

## Usage

### Create Your Stack

```bash
$ ./security_monkey_stack.rb expand > security_monkey.json
$ aws cloudformation validate-template --template-body file://security_monkey.json
$ aws cloudformation create-stack --stack-name security-monkey-stack \
   --template-body file://security_monkey.json \
   --parameters '[{"ParameterKey":"KeyName", "ParameterValue":"YOUR_EC2_KEY_NAME_HERE"}, {"ParameterKey":"EmailAddress", "ParameterValue":"YOUR_EMAIL_ADDRESS_HERE"}]'
```

After your stack is created succesfully, check your email and confirm the email notification subscription from AWS. You are looking for an email with the subject line: AWS Notification - Subscription Confirmation

### Delete Your Stack

If your stack creation fails or you wish to stop being billed for the AWS resources, you will need to run:

```bash
$ aws cloudformation delete-stack --stack-name security-monkey-stack
```

###


