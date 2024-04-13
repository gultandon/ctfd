output "cloudfront_url" {
  description = "HTTPS URL for CTFd via CloudFront — share this with players once setup is complete"
  value       = "https://${aws_cloudfront_distribution.ctfd.domain_name}"
}

output "ec2_public_ip" {
  description = "EC2 Elastic IP address"
  value       = aws_eip.ctfd.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the CTFd server"
  value       = "ssh -i ctfd-key.pem ec2-user@${aws_eip.ctfd.public_ip}"
}
