output "jenkins_public_ip" {
  description = "Public IP of Jenkins server"
  value       = aws_instance.jenkins.public_ip
}

output "zabbix_public_ip" {
  description = "Public IP of Zabbix server"
  value       = aws_instance.zabbix.public_ip
}

output "appserver_public_ip" {
  description = "Public IP of Application server"
  value       = aws_instance.appserver.public_ip
}

output "jenkins_url" {
  description = "Jenkins Web UI URL"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "zabbix_url" {
  description = "Zabbix Web UI URL"
  value       = "http://${aws_instance.zabbix.public_ip}/zabbix"
}