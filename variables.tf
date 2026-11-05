variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "k6_version" {
  type        = string
  default     = "2.3.0"
  description = "k6 release to install from GitHub, without the v. Change checksums with it."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.k6_version))
    error_message = "k6_version is a release number such as \"2.3.0\"."
  }
}

variable "checksums" {
  type        = map(string)
  description = "SHA-256 of the release tarball for each architecture, from the release's k6-v<version>-checksums.txt. Change these with k6_version."
  default = {
    amd64 = "39c3117b6af817592dcd0ce4242105c0a7af10948c2a425306f0be8f7a8a8ab1"
    arm64 = "5ca3433e8201da72a284aaa241a1bb5fb47f4abb4e384d39410ddd8062f49b90"
  }

  validation {
    condition     = alltrue([for a in ["amd64", "arm64"] : can(regex("^[0-9a-f]{64}$", lookup(var.checksums, a, "")))])
    error_message = "checksums needs a SHA-256, in lowercase hex, for both amd64 and arm64."
  }
}
