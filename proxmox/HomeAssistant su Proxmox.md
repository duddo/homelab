# HomeAssistant su Proxmox

Creata VM su Proxmox da riga di comando.
```
wget https://github.com/home-assistant/operating-system/releases/download/${BRANCH}/haos_ova-${BRANCH}.qcow2.xz

unxz haos_ova-${BRANCH}.qcow2.xz

qm create 200 -agent 1 -tablet 0 -localtime 1 -bios ovmf -cpu host -cores 2 -memory 4096 -name homeassistant -net0 virtio,bridge=vmbr0 -onboot 1 -ostype l26 -scsihw virtio-scsi-pci

pvesm alloc local-lvm 200 vm-200-disk-0 4M

qm importdisk 200 haos-image/haos_ova-15.2.qcow2 local-lvm

qm set 200 -efidisk0 local-lvm:vm-200-disk-0,efitype=4m -scsi0 local-lvm:vm-200-disk-1,cache=writethrough,discard=on,ssd=1,size=32G -boot order=scsi0 -description "Home Assistant OS"

qm start 200

```

attacca la usb, poi
```
lsusb
```
Perfect! Your SONOFF Zigbee 3.0 USB Dongle Plus V2 has:
Vendor ID: 1a86
Product ID: 55d4

```
qm set 200 -usb0 host=1a86:55d4

qm stop 200
qm start 200
```