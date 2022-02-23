# ---------------------------------------------------------------------------------------------------------------------
# IAM Role for use by an EC2 instance of Jenkins Controller to give access to :
#   1) Register DNS record to Route53 for our ec2 host
#   2) Jenkins Controller manipulate EC2 for launching Jenkins Worker EC2 instance
#   3) Jenkins Controller get config files from S3
#   4) Cloudwatch logging and metrics
#   5) Check AutoScalingGroup for number of instances so can delay mounting EFS until no instances using it.
#   6) Send SNS messages for alerting
#   7) Send Update on instance health to the ASG
#   8) Get secret for jenkins admin password
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "jenkins-controller" {
  name                 = "${var.resource_name_prefix}-jenkins-controller"
  max_session_duration = 43200
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags                 = var.tags
}

# 1) Register DNS record to Route53 for our ec2 host
resource "aws_iam_policy" "route53" {
  name        = "${var.resource_name_prefix}-nexus-route53"
  description = "RegisterDNSwithRoute53"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Route53registerDNS",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:GetHostedZone",
        "route53:ListResourceRecordSets"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:route53:::hostedzone/${var.route53_private_zone_id}"
      ]
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "route53" {
  role       = aws_iam_role.jenkins-controller.name
  policy_arn = aws_iam_policy.route53.arn
}

# 2) Jenkins Controller manipulate EC2 for launching Jenkins Worker EC2 instance
# TODO : restrict this policy by Resource to jenkins-workers only - otherwise to much power !
resource "aws_iam_policy" "jenkins-controller-ec2" {
  name        = "${var.resource_name_prefix}-jenkins-controller-ec2"
  description = "ReadWrite access to EC2 for Jenkins Controller to launch/terminate EC2 instances for Jenkins Nodes."
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "jenkinsec2",
      "Action": [
        "ec2:DescribeSpotInstanceRequests",
        "ec2:CancelSpotInstanceRequests",
        "ec2:GetConsoleOutput",
        "ec2:RequestSpotInstances",
        "ec2:RunInstances",
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeInstances",
        "ec2:DescribeKeyPairs",
        "ec2:DescribeRegions",
        "ec2:DescribeImages",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "iam:ListInstanceProfilesForRole",
        "iam:PassRole",
        "ec2:GetPasswordData"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "jenkins-controller-ec2" {
  role       = aws_iam_role.jenkins-controller.name
  policy_arn = aws_iam_policy.jenkins-controller-ec2.arn
}

# 3) Jenkins Controller get config files from S3
resource "aws_iam_policy" "jenkins-controller-s3" {
  name        = "${var.resource_name_prefix}-jenkins-controller-s3"
  description = "Read access to s3 bucket for Jenkins Controller config files"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "JenkinsReadS3",
      "Action": [
        "s3:List*",
        "s3:GetObject*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "jenkins-controller-s3" {
  role       = aws_iam_role.jenkins-controller.name
  policy_arn = aws_iam_policy.jenkins-controller-s3.arn
}

# 4) Cloudwatch logging and metrics - To allow output of metrics and logs to Cloudwatch
resource "aws_iam_role_policy_attachment" "jenkins-controller-cloudwatch" {
  role       = aws_iam_role.jenkins-controller.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# 5) Check AutoScalingGroup for number of instances so can delay mounting EFS until no instances using it.
resource "aws_iam_role_policy_attachment" "jenkins-controller-asg" {
  role       = aws_iam_role.jenkins-controller.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingReadOnlyAccess"
}

# 6) Send SNS messages for alerting
resource "aws_iam_policy" "jenkins-controller-sns" {
  name        = "${var.resource_name_prefix}-jenkins-controller-sns"
  description = "Add ability to send SNS alert message"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sns:Publish"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
  #      "Resource": "arn::sns:${aws_region}:${account_id}:*"
}
resource "aws_iam_role_policy_attachment" "jenkins-controller-sns" {
  role       = aws_iam_role.jenkins-controller.name
  policy_arn = aws_iam_policy.jenkins-controller-sns.arn
}

# 7) Send Update on instance health to the ASG
resource "aws_iam_policy" "jenkins-controller-asg-health" {
  name        = "${var.resource_name_prefix}-jenkins-controller-asg-health"
  description = "Send Update on instance health to the ASG"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "autoscaling:SetInstanceHealth"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "jenkins-controller-asg-health" {
  role       = aws_iam_role.jenkins-controller.name
  policy_arn = aws_iam_policy.jenkins-controller-asg-health.arn
}

# 8) Get secret for jenkins admin password
resource "aws_iam_policy" "jenkins-controller-get-secrets" {
  name        = "${var.resource_name_prefix}-jenkins-controller-get-secrets"
  description = "Get secret for jenkins admin password"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetSecretsForJenkins"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.secrets_arns
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "jenkins-controller-get-secrets" {
  role       = aws_iam_role.jenkins-controller.name
  policy_arn = aws_iam_policy.jenkins-controller-get-secrets.arn
}

resource "aws_iam_instance_profile" "jenkins-controller" {
  name = "jenkins-controller"
  role = aws_iam_role.jenkins-controller.name
}
