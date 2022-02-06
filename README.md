# iam-glass

Terraform module for creating IAM Role and Profile for attaching to GLASS EC2 instances to give access to :
* Cloudwatch logging and metrics
* Check AutoScalingGroup for number of instances so can delay mounting EFS until no instances using it.
* Check for matching GLASS instances by Hazelcast Discovery to join to its Cluster. 