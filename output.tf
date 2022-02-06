# Output values
#
output "jenkins-controller-role" {
  value = aws_iam_role.jenkins-controller
}
output "jenkins-controller-profile" {
  value = aws_iam_instance_profile.jenkins-controller
}