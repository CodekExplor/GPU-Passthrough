#!/bin/bash

set -e

echo "[1/7] Backup i modyfikacja GRUB..."

cp /etc/default/grub /etc/default/grub.bak

# Zamień tylko jedną linię
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on vfio-pci.ids=8086:1912 i915.enable_gvt=1"/' /etc/default/grub

update-grub

echo "[2/7] Dodawanie modułów VFIO..."

cat <<EOF > /etc/modules
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
kvmgt
EOF

echo "[3/7] Konfiguracja opcji IOMMU..."

echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/iommu_unsafe_interrupts.conf
echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm.conf

echo "[4/7] Blacklistowanie sterowników GPU i Wi-Fi..."

cat <<EOF > /etc/modprobe.d/blacklist.conf
blacklist nouveau
blacklist nvidia
blacklist radeon
blacklist amdgpu
blacklist i915
blacklist mt76x2u
EOF

echo "[5/7] Konfiguracja VFIO..."

echo "options vfio-pci ids=8086:1912,00:1f.3 disable_vga=1" > /etc/modprobe.d/vfio.conf

echo "[6/7] Aktualizacja initramfs..."
update-initramfs -u

echo "[7/7] Konfiguracja QEMU dla maszyny wirtualnej..."
read -p "Podaj numer maszyny wirtualnej (VMID): " VMID

VM_CONF="/etc/pve/qemu-server/${VMID}.conf"

if [ ! -f "$VM_CONF" ]; then
    echo "❌ Plik konfiguracyjny VM ${VMID} nie istnieje: $VM_CONF"
    exit 1
fi

# Usuń istniejące linie args, jeśli występują
sed -i '/^args:/d' "$VM_CONF"

# Dodaj poprawną linię args
echo 'args: -cpu host,kvm=off -vnc 0.0.0.0:1 -device vfio-pci,host=00:02.0,romfile=/var/lib/vz/dump/i915ovmf.rom,x-igd-opregion=on' >> "$VM_CONF"

echo "✅ Konfiguracja zakończona."
read -p "Czy chcesz teraz zrestartować system? (t/n): " confirm
if [[ "$confirm" == "t" || "$confirm" == "T" ]]; then
    reset
else
    echo "➡️ Uruchom ponownie system później, aby zastosować zmiany."
fi
