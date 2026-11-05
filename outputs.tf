output "k6_version" {
  description = "k6 release installed."
  value       = var.k6_version
}

output "k6_path" {
  description = "Path of the k6 command on each host."
  value       = "/usr/local/bin/k6"
}
