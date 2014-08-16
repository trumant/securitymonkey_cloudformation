#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'
require 'open-uri'

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'Creates a CloudFormation stack with AutoScaling Group, EC2 instance, RDS db, CloudWatch alerting and security group suitable for running Security Monkey'

  parameter 'InstanceType',
            :Description => 'EC2 instance type',
            :Type => 'String',
            :Default => 'm3.medium'

  parameter 'KeyName',
            :Description => 'Name of your key pair for instance',
            :Type => 'String'

  parameter 'DatabaseName',
            :Description => 'The name of the database to be used',
            :Type => 'String',
            :Default => 'security_monkey'

  parameter 'DatabaseUserName',
            :Description => 'The name of the user that will connect to the database',
            :Type => 'String',
            :Default => 'security_monkey'

  parameter 'DatabasePassword',
            :Description => 'The password connect to the database',
            :Type => 'String',
            :Default => 'sec_mky_password'

  parameter 'DatabasePort',
            :Description => 'The port to connect to the DB',
            :Type => 'String',
            :Default => '5432'

  parameter 'DbClass',
            :Description => 'RDS instance size',
            :Type => 'String',
            :Default => 'db.m3.medium'

  parameter 'AllocatedStorage',
            :Description => 'RDS instance storage size in GB',
            :Type => 'String',
            :Default => '5'

  parameter 'EmailAddress',
            :Description => 'Email to where notifications will be sent',
            :Type => 'String'

  parameter 'AMI',
            :Description => 'The EC2 AMI to use',
            :Type => 'String',
            :Default => 'ami-cc4d9fa4'

  parameter 'CidrIp',
            :Description => 'The CidrIp range that will be allowed to ssh to your EC2 instance',
            :Type => 'String',
            :Default => "#{open("http://api.ipify.org").read}/32"

  resource 'EmailTopic', :Type => 'AWS::SNS::Topic', :Properties => {
      :Subscription => [
          {
              :Endpoint => ref('EmailAddress'),
              :Protocol => 'email',
          },
      ],
  }

  resource 'SecurityMonkeyRole', :Type => 'AWS::IAM::Role', :Properties => {
      :AssumeRolePolicyDocument => {
          :Version => '2012-10-17',
          :Statement => [
              {
                  :Effect => 'Allow',
                  :Principal => { :Service => [ 'ec2.amazonaws.com' ] },
                  :Action => [ 'sts:AssumeRole' ],
              },
          ],
      },
      :Path => '/security_monkey_role/',
      :Policies => [
          {
              :PolicyName => 'security_monkey_read_only',
              :PolicyDocument => {
                  :Statement => [
                      {
                          :Action => [
                              'cloudwatch:Describe*',
                              'cloudwatch:Get*',
                              'cloudwatch:List*',
                              'ec2:Describe*',
                              'elasticloadbalancing:Describe*',
                              'iam:List*',
                              'iam:Get*',
                              'route53:Get*',
                              'route53:List*',
                              'rds:Describe*',
                              's3:Get*',
                              's3:List*',
                              'sdb:GetAttributes',
                              'sdb:List*',
                              'sdb:Select*',
                              'ses:Get*',
                              'ses:List*',
                              'sns:Get*',
                              'sns:List*',
                              'sqs:GetQueueAttributes',
                              'sqs:ListQueues',
                              'sqs:ReceiveMessage',
                          ],
                          :Effect => 'Allow',
                          :Resource => '*',
                      },
                  ],
              },
          },
      ],
  }

  resource 'SecurityMonkeyInstanceProfile', :Type => 'AWS::IAM::InstanceProfile', :Properties => {
      :Path => '/security_monkey_instance_profile/',
      :Roles => [ ref('SecurityMonkeyRole') ],
  }

  resource 'SecurityMonkeySecurityGroup', :Type => 'AWS::EC2::SecurityGroup', :Properties => {
      :GroupDescription => 'Group for the security monkey instance',
      :SecurityGroupIngress => [
          {
              :IpProtocol => 'tcp',
              :FromPort => '80',
              :ToPort => '80',
              :CidrIp => "0.0.0.0/0"
          },
          {
              :IpProtocol => 'tcp',
              :FromPort => '22',
              :ToPort => '22',
              :CidrIp => ref('CidrIp'),
          },
      ],
  }

  resource 'SecurityMonkeyDbSecurityGroup', :Type => 'AWS::RDS::DBSecurityGroup', :Properties => {
      :DBSecurityGroupIngress => { :EC2SecurityGroupName => ref('SecurityMonkeySecurityGroup') },
      :GroupDescription => 'Frontend Access',
  }

  resource 'SecurityMonkeyRDS', :Type => 'AWS::RDS::DBInstance', :Properties => {
      :AllowMajorVersionUpgrade => true,
      :AutoMinorVersionUpgrade => true,
      :DBInstanceIdentifier => 'security-monkey-rds',
      :DBName => ref('DatabaseName'),
      :Engine => 'postgres',
      :Port => ref('DatabasePort'),
      :MasterUsername => ref('DatabaseUserName'),
      :MasterUserPassword => ref('DatabasePassword'),
      :DBInstanceClass => ref('DbClass'),
      :DBSecurityGroups => [ ref('SecurityMonkeyDbSecurityGroup') ],
      :AllocatedStorage => ref('AllocatedStorage'),
  }

  resource 'SecurityMonkeyLaunchConfig', :Type => 'AWS::AutoScaling::LaunchConfiguration', :Properties => {
      :IamInstanceProfile => get_att('SecurityMonkeyInstanceProfile', 'Arn'),
      :KeyName => ref('KeyName'),
      :ImageId => ref('AMI'),
      :SecurityGroups => [ ref('SecurityMonkeySecurityGroup') ],
      :InstanceType => ref('InstanceType'),
  }

  resource 'SecurityMonkeyAutoScalingGroup', :Type => 'AWS::AutoScaling::AutoScalingGroup', :Properties => {
      :NotificationConfiguration => {
        :TopicARN => ref('EmailTopic'),
        :NotificationTypes => [ 'autoscaling:EC2_INSTANCE_LAUNCH_ERROR', 'autoscaling:EC2_INSTANCE_TERMINATE_ERROR' ]
      },
      :AvailabilityZones => [ 'us-east-1a', 'us-east-1c', 'us-east-1d' ],
      :LaunchConfigurationName => ref('SecurityMonkeyLaunchConfig'),
      :MinSize => '1',
      :MaxSize => '1',
  }

  resource 'DBCPUAlarm', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmDescription => 'CPU exceeds 85% for 30+ minutes',
      :MetricName => 'CPUUtilization',
      :Namespace => 'AWS/RDS',
      :Statistic => 'Average',
      :Period => '900',
      :EvaluationPeriods => '2',
      :Threshold => '85',
      :AlarmActions => [ ref('EmailTopic') ],
      :Dimensions => [
          {
              :Name => 'DBInstanceIdentifier',
              :Value => ref('SecurityMonkeyRDS'),
          },
      ],
      :ComparisonOperator => 'GreaterThanThreshold'
  }

  resource 'DBStorageAlarm', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmDescription => 'Storage available below 1gb for 30+ minutes',
      :MetricName => 'FreeStorageSpace',
      :Namespace => 'AWS/RDS',
      :Statistic => 'Average',
      :Period => '900',
      :EvaluationPeriods => '2',
      :Threshold => '1000000000',
      :AlarmActions => [ ref('EmailTopic') ],
      :Dimensions => [
          {
              :Name => 'DBInstanceIdentifier',
              :Value => ref('SecurityMonkeyRDS'),
          },
      ],
      :ComparisonOperator => 'LessThanThreshold',
  }

  output 'DatabaseAddress',
         :Value => get_att('SecurityMonkeyRDS', 'Endpoint.Address')

  output 'DatabaseName',
         :Value => ref('DatabaseName')

  output 'DatabaseUserName',
         :Value => ref('DatabaseUserName')

  output 'DatabasePassword',
         :Value => ref('DatabasePassword')

  output 'DatabasePort',
         :Value => get_att('SecurityMonkeyRDS', 'Endpoint.Port')

end.exec!
