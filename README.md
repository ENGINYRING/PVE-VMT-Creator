[![ENGINYRING](https://cdn.enginyring.com/img/logo_dark.png)](https://www.enginyring.com)

# PVE-VMT-Creator

**Proxmox VM Template Creator** - An automated bash script to download, customize, and create VM templates in Proxmox VE from cloud images.

## 🚀 Features

- **Universal Image Support**: Works with any cloud image format (qcow2, img, raw, etc.)
- **Automatic Format Conversion**: Converts images to qcow2 format automatically
- **Interactive Mode**: Prompts for all parameters when run without arguments
- **Command-Line Mode**: Supports scripting with command-line arguments
- **Dependency Management**: Checks and optionally installs required packages
- **Cloud-Init Ready**: Configures templates with cloud-init support
- **QEMU Guest Agent**: Automatically installs qemu-guest-agent in templates
- **SSH Configuration**: Enables root login and password authentication
- **Error Handling**: Comprehensive error checking throughout the process

## 📋 Prerequisites

- Proxmox VE 6.0 or higher
- Root access or sudo privileges
- Internet connection for downloading cloud images
- The script will prompt to install required packages if missing:
  - `libguestfs-tools`
  - `qemu-utils`
  - `wget`

## 🔧 Installation

```bash
# Download the script
wget -O create-template.sh https://raw.githubusercontent.com/ENGINYRING/PVE-VMT-Creator/refs/heads/main/create-template.sh

# Make the script executable
chmod +x create-template.sh
```

## 📖 Usage

### Interactive Mode

Run the script without any arguments to enter interactive mode:

```bash
./create-template.sh
```

You'll be prompted to enter:
- **Image URL** (required): The URL to download the cloud image from
- **Volume Name** (optional, default: `local-lvm`): Proxmox storage volume name
- **VM ID** (optional, default: `9000`): Unique VM identifier
- **Template Name** (optional, default: `cloud-tpl`): Name for the template
- **CPU Cores** (optional, default: `2`): Number of CPU cores
- **Memory** (optional, default: `2048`): Memory in MB
- **CPU Type** (optional, default: `host`): CPU type for the VM

### Command-Line Mode

```bash
./create-template.sh <imageURL> [volumeName] [vmID] [templateName] [cores] [memory] [cpuType]
```

**Parameters:**
1. `imageURL` - (Required) URL to the cloud image
2. `volumeName` - (Optional) Storage volume name (default: local-lvm)
3. `vmID` - (Optional) VM ID (default: 9000)
4. `templateName` - (Optional) Template name (default: cloud-tpl)
5. `cores` - (Optional) Number of CPU cores (default: 2)
6. `memory` - (Optional) Memory in MB (default: 2048)
7. `cpuType` - (Optional) CPU type (default: host)

## 💡 Examples

### Ubuntu 22.04 (Jammy)

```bash
./create-template.sh https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

### Ubuntu 24.04 (Noble)

```bash
./create-template.sh https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img local-lvm 9001 ubuntu-noble 4 4096
```

### Debian 12 (Bookworm)

```bash
./create-template.sh https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 local-lvm 9002 debian-12
```

### Rocky Linux 9

```bash
./create-template.sh https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 local-lvm 9003 rocky-9
```

### Fedora Cloud

```bash
./create-template.sh https://download.fedoraproject.org/pub/fedora/linux/releases/39/Cloud/x86_64/images/Fedora-Cloud-Base-39-1.5.x86_64.qcow2 local-lvm 9004 fedora-39
```

## 🔄 Using the Template

After creating a template, clone it to create new VMs:

```bash
# Clone the template
qm clone 9000 100 --name my-vm

# Configure cloud-init (username and password)
qm set 100 --ciuser ubuntu --cipassword mypassword

# Or use SSH keys (recommended)
qm set 100 --ciuser ubuntu --sshkeys ~/.ssh/id_rsa.pub

# Optional: Set static IP
qm set 100 --ipconfig0 ip=192.168.1.100/24,gw=192.168.1.1

# Start the VM
qm start 100
```

## ⚙️ What the Script Does

1. **Validates Dependencies**: Checks for required packages and offers to install them
2. **Downloads Image**: Fetches the cloud image from the provided URL
3. **Customizes Image**:
   - Installs qemu-guest-agent
   - Enables root SSH login
   - Enables password authentication
4. **Converts Format**: Converts image to qcow2 if necessary
5. **Creates VM**: 
   - Creates a new VM with specified resources
   - Imports the disk
   - Configures cloud-init
   - Sets up networking (DHCP by default)
6. **Converts to Template**: Finalizes the VM as a reusable template

## 🐛 Troubleshooting

### Image Download Fails

Ensure you have internet connectivity and the URL is correct. Some images may require specific user agents or headers.

### Libguestfs Errors

If you encounter errors with `virt-customize`, try:
```bash
export LIBGUESTFS_BACKEND=direct
./create-template.sh <parameters>
```

### VM ID Already Exists

The script will automatically destroy existing VMs with the same ID. Ensure you don't accidentally overwrite important VMs.

### Storage Volume Not Found

List available storage volumes:
```bash
pvesm status
```

Use the correct volume name from the output.

## 🔐 Security Notes

- The script enables root login and password authentication for convenience
- For production use, consider:
  - Disabling password authentication
  - Using SSH keys only
  - Creating non-root users via cloud-init
  - Configuring firewall rules

## 📝 Cloud-Init Configuration Examples

### Set hostname and timezone

```bash
qm set 100 --ciuser admin --cipassword secret
qm set 100 --nameserver 8.8.8.8 --searchdomain example.com
```

### Add multiple SSH keys

```bash
cat > /tmp/ssh-keys.txt << EOF
ssh-rsa AAAAB3NzaC1... user1@host
ssh-rsa AAAAB3NzaC1... user2@host
EOF

qm set 100 --sshkeys /tmp/ssh-keys.txt
```

### Custom cloud-init script

```bash
qm set 100 --cicustom "user=local:snippets/user-data.yaml"
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🔗 Useful Links

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
- [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/)
- [Debian Cloud Images](https://cloud.debian.org/images/cloud/)

## 👤 Author

**ENGINYRING**

- GitHub: [@ENGINYRING](https://github.com/ENGINYRING)
- [**ENGINYRING**: Hosting • VPS • Domains • CAD/BIM](https://www.enginyring.com)

---

⭐ If you find this project helpful, please give it a star!
