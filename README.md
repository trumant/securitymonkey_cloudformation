# securitymonkey_cloudformation - Stand up an AWS CloudFormation stack running [SecurityMonkey](https://github.com/Netflix/security_monkey)

This CloudFormation stack creates an AutoScaling Group guaranteeing a single EC2 instance, running SecurityMonkey and storing data in an RDS db. Both the EC2 instance and RDS db are configured with security groups. Simple CloudWatch RDS monitoring is also created. All notifications and alerts from monitoring and the AutoScaling group are published to an SNS topic that will email the provided address.

## Requirements

- AWS Account
- Install and configure [aws-cli](https://github.com/aws/aws-cli#installation)
- Ruby 1.9.3, Bundler

## Stack Parameters

## Usage

```bash
$ ./security_monkey_stack.rb expand > security_monkey.json
$ aws cloudformation validate-template --template-body file://security_monkey.json
$ aws cloudformation create-stack --stack-name security_monkey_stack \
   --template-body file:security_monkey.json \
   --parameters ' [{"ParameterKey":"name", "ParameterValue":"test"}]'
```
