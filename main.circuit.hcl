# Facts give each host's architecture, which picks the release tarball.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }
}

locals {
  arch    = { x86_64 = "amd64", aarch64 = "arm64" }
  home    = "/opt/k6/${var.k6_version}"
  release = { for k, f in data.conn3x_host.facts : k => "k6-v${var.k6_version}-linux-${local.arch[f.arch]}" }
}

circuit "k6" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "tools" {
    for_each = toset(["curl", "tar", "gzip"])
    package {
      name = item.value
    }
  }

  # The tarball from the GitHub release rather than Grafana's apt or rpm
  # repository: a version and a checksum fixed here can't move under you,
  # and the same steps work on every distribution.
  step "download" {
    download {
      url    = "https://github.com/grafana/k6/releases/download/v${var.k6_version}/${local.release[each.key]}.tar.gz"
      sha256 = var.checksums[local.arch[data.conn3x_host.facts[each.key].arch]]
      dest   = "/opt/k6/${local.release[each.key]}.tar.gz"
    }
  }

  step "unpack" {
    archive {
      src     = "/opt/k6/${local.release[each.key]}.tar.gz"
      dest    = local.home
      creates = "${local.home}/${local.release[each.key]}/k6"
    }
  }

  step "link" {
    link {
      path   = "/usr/local/bin/k6"
      target = "${local.home}/${local.release[each.key]}/k6"
    }
  }
}
