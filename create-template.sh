#!/bin/bash

# Check if running in interactive mode (no arguments provided)
if [ $# -eq 0 ]; then
    echo "============================================"
    echo "Proxmox VM Template Creator - Interactive Mode"
    echo "============================================"
    echo
    
    # Image URL (required)
    read -p "Enter image URL: " imageURL
    while [ -z "$imageURL" ]; do
        echo "Error: Image URL is required."
        read -p "Enter image URL: " imageURL
    done
    
    # Volume Name (optional)
    read -p "Enter volume name (optional, default: local-lvm): " volumeName
    volumeName="${volumeName:-local-lvm}"
    
    # VM ID (optional)
    read -p "Enter VM ID (optional, default: 9000): " virtualMachineId
    virtualMachineId="${virtualMachineId:-9000}"
    
    # Template Name (optional)
    read -p "Enter template name (optional, default: cloud-tpl): " templateName
    templateName="${templateName:-cloud-tpl}"
    
    # CPU Cores (optional)
    read -p "Enter number of CPU cores (optional, default: 2): " tmp_cores
    tmp_cores="${tmp_cores:-2}"
    
    # Memory (optional)
    read -p "Enter memory in MB (optional, default: 2048): " tmp_memory
    tmp_memory="${tmp_memory:-2048}"
    
    # CPU Type (optional)
    read -p "Enter CPU type (optional, default: host): " cpuTypeRequired
    cpuTypeRequired="${cpuTypeRequired:-host}"
    
    echo
else
    # Command line arguments mode
    imageURL="$1"
    volumeName="${2:-local-lvm}"
    virtualMachineId="${3:-9000}"
    templateName="${4:-cloud-tpl}"
    tmp_cores="${5:-2}"
    tmp_memory="${6:-2048}"
    cpuTypeRequired="${7:-host}"
fi

# Extract image name from URL
imageName=$(basename "$imageURL")

echo "============================================"
echo "Proxmox VM Template Creator"
echo "============================================"
echo "Image URL: $imageURL"
echo "Image Name: $imageName"
echo "Volume: $volumeName"
echo "VM ID: $virtualMachineId"
echo "Template Name: $templateName"
echo "CPU Cores: $tmp_cores"
echo "Memory: $tmp_memory MB"
echo "CPU Type: $cpuTypeRequired"
echo "============================================"
echo

# Check if libguestfs-tools is installed
if ! dpkg -l | grep -q "^ii  libguestfs-tools"; then
    echo "libguestfs-tools is not installed."
    echo "This package is required to customize the cloud image."
    echo
    read -p "Would you like to install libguestfs-tools now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Updating package lists..."
        apt update
        echo "Installing libguestfs-tools..."
        apt install libguestfs-tools -y
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install libguestfs-tools"
            exit 1
        fi
        echo "libguestfs-tools installed successfully."
    else
        echo "Installation cancelled. Cannot proceed without libguestfs-tools."
        exit 1
    fi
else
    echo "libguestfs-tools is already installed."
fi

# Check if qemu-utils is installed (needed for qemu-img)
if ! command -v qemu-img &> /dev/null; then
    echo
    echo "qemu-img is not installed."
    echo "This package is required to convert image formats."
    echo
    read -p "Would you like to install qemu-utils now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing qemu-utils..."
        apt install qemu-utils -y
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install qemu-utils"
            exit 1
        fi
        echo "qemu-utils installed successfully."
    else
        echo "Installation cancelled. Cannot proceed without qemu-utils."
        exit 1
    fi
else
    echo "qemu-utils is already installed."
fi

echo

# Clean up any existing image files with the same name
if [ -f "$imageName" ]; then
    echo "Removing existing image file: $imageName"
    rm -f "$imageName"
fi

# Download the image
echo "Downloading image from $imageURL..."
wget -O "$imageName" "$imageURL"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download image"
    exit 1
fi

echo "Image downloaded successfully."
echo

# Check if VM already exists and destroy it
if qm status $virtualMachineId &>/dev/null; then
    echo "VM $virtualMachineId already exists. Destroying it..."
    qm destroy $virtualMachineId
fi

echo "Enabling root password authentication in sshd_config..."
# Use virt-customize to run a sed command that modifies sshd_config
# This command finds the 'PermitRootLogin' line (potentially commented out) and sets it to 'yes'
virt-customize -a "$imageName" --run-command "sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
if [ $? -ne 0 ]; then
    echo "Error: Failed to modify sshd_config to enable root login"
    exit 1
fi

# Optional: Also ensure PasswordAuthentication is enabled (default is often yes, but good to check)
echo "Ensuring SSH password authentication is enabled..."
virt-customize -a "$imageName" --run-command "sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"
if [ $? -ne 0 ]; then
    echo "Error: Failed to modify sshd_config to enable password authentication"
    exit 1
fi

# Convert to qcow2 if not already in that format
echo "Checking image format..."
imageFormat=$(qemu-img info "$imageName" | grep "file format:" | awk '{print $3}')
echo "Detected format: $imageFormat"

if [ "$imageFormat" != "qcow2" ]; then
    echo "Converting image to qcow2 format..."
    qcow2ImageName="${imageName%.*}.qcow2"
    qemu-img convert -f "$imageFormat" -O qcow2 "$imageName" "$qcow2ImageName"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to convert image to qcow2"
        exit 1
    fi
    # Remove original and use qcow2 version
    rm -f "$imageName"
    imageName="$qcow2ImageName"
    echo "Image converted to qcow2: $imageName"
else
    echo "Image is already in qcow2 format."
fi

# Create the VM
echo "Creating VM $virtualMachineId..."
qm create $virtualMachineId --name "$templateName" --memory $tmp_memory --cores $tmp_cores --net0 virtio,bridge=vmbr0
if [ $? -ne 0 ]; then
    echo "Error: Failed to create VM"
    exit 1
fi

# Import disk
echo "Importing disk as qcow2 format..."
importOutput=$(qm importdisk $virtualMachineId "$imageName" $volumeName --format qcow2 2>&1)
echo "$importOutput"

if [ $? -ne 0 ]; then
    echo "Error: Failed to import disk"
    exit 1
fi

echo ""
echo "Extracting disk reference..."

# Extract the disk reference from import output
# The output contains something like "unused0: successfully imported disk 'local:9002/vm-9002-disk-0.qcow2'"
diskReference=$(echo "$importOutput" | grep -oP "successfully imported disk '\K[^']+")

if [ -z "$diskReference" ]; then
    echo "Error: Could not determine disk reference from import output"
    echo "Import output was:"
    echo "$importOutput"
    exit 1
fi

echo "Disk reference found: $diskReference"
echo ""

# Configure VM hardware and attach disk
echo "Configuring VM hardware..."

# Set SCSI controller
qm set $virtualMachineId --scsihw virtio-scsi-pci
if [ $? -ne 0 ]; then
    echo "Error: Failed to set SCSI controller"
    exit 1
fi

# Attach the imported disk to scsi0 using the correct disk reference
echo "Attaching disk to SCSI0..."
qm set $virtualMachineId --scsi0 "$diskReference"
if [ $? -ne 0 ]; then
    echo "Error: Failed to attach disk"
    exit 1
fi

# Set boot order and boot disk
echo "Configuring boot settings..."
qm set $virtualMachineId --boot order=scsi0
if [ $? -ne 0 ]; then
    echo "Error: Failed to set boot order"
    exit 1
fi

# Add Cloud-Init drive
echo "Adding Cloud-Init drive..."
qm set $virtualMachineId --ide2 $volumeName:cloudinit
if [ $? -ne 0 ]; then
    echo "Error: Failed to add Cloud-Init drive"
    exit 1
fi

# Configure serial console
echo "Configuring serial console..."
qm set $virtualMachineId --serial0 socket --vga serial0
if [ $? -ne 0 ]; then
    echo "Error: Failed to configure serial console"
    exit 1
fi

# Configure network with DHCP
echo "Configuring network..."
qm set $virtualMachineId --ipconfig0 ip=dhcp
if [ $? -ne 0 ]; then
    echo "Error: Failed to configure network"
    exit 1
fi

# Set CPU type
echo "Setting CPU type..."
qm set $virtualMachineId --cpu cputype=$cpuTypeRequired
if [ $? -ne 0 ]; then
    echo "Error: Failed to set CPU type"
    exit 1
fi

# Convert to template
echo "Converting VM to template..."
qm template $virtualMachineId

echo
echo "============================================"
echo "Template created successfully!"
echo "VM ID: $virtualMachineId"
echo "Template Name: $templateName"
echo "============================================"
echo
echo "You can now clone this template to create new VMs:"
echo "  qm clone $virtualMachineId <new-vm-id> --name <new-vm-name>"
echo
echo "Note: Cloud-init will handle user configuration. You can set it with:"
echo "  qm set <new-vm-id> --ciuser <username> --cipassword <password> --sshkeys <ssh-key-file>"
echo
echo "Script usage:"
echo "  Interactive mode: ./script.sh"
echo "  With arguments:   ./script.sh <imageURL> [volumeName] [vmID] [templateName] [cores] [memory] [cpuType]"
