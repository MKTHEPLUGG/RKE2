# https://github.com/nbarnum/packer-ubuntu-cloud-image/tree/main
# when building this template supply a variable for the password for the ubuntu user in the .pkrvars file
# sudo packer build -var-file=variables.pkrvars.hcl .
packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

source "qemu" "armbian" {
  accelerator      = var.qemu_accelerator
  cd_files         = ["./cloud-init/*"]
  cd_label         = "cidata"
  disk_compression = true
  disk_image       = true
  disk_size        = "10G"
  headless         = true
  iso_checksum     = "sha256:15dd545fb0c829b1e8fd3ddd431cf4e42614baed99910a60f33d50e4caf9cde9"
  iso_url          = var.iso_url
  output_directory = "output-armbian"
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
  ssh_password     = "ubuntu"
  ssh_username     = "ubuntu"
  vm_name          = "armbian-edgecloud.img"
  qemuargs = [
    ["-m", "2048M"],
    ["-smp", "2"],
    ["-serial", "mon:stdio"],
  ]
}

build {
  sources = ["source.qemu.armbian"]

  provisioner "file" {
  source      = "scripts/.p10k.zsh"       # Local path relative to Packer host
  destination = "~/.p10k.zsh"             # copy to ubuntu user home dir
  }


  provisioner "shell" {
    // run scripts with sudo, as the default cloud image user is unprivileged
    execute_command = "echo 'packer' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    // NOTE: cleanup.sh should always be run last, as this performs post-install cleanup tasks
    scripts = [
      "scripts/install.sh",
      "scripts/cleanup.sh"
    ]

    environment_vars = [
      "USER_PASSWORD=${var.user_password}"
    ]
  }

  post-processor "shell-local" {
    inline = [
      "if [ \"${var.output_raw}\" = true ]; then qemu-img convert -f qcow2 -O raw output-${var.ubuntu_version}/ubuntu-${var.ubuntu_version}.img output-${var.ubuntu_version}/ubuntu-${var.ubuntu_version}.raw; fi"
    ]
  }
}