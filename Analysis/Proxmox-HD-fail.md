# 2026-03-01 Proxmox startup fail

## Situation assestment

Due giorni fa il server proxmox è stato trovato acceso ma offline.

Collegando un monitor e riavviando GRUB si vede correttamente, ma avviandolo, si vedono diversi errori legati al I/O.

Con l'ultimo kernel il boot rimane bloccato a lungo su `loading initial ramdisk`, mostra `found volume group pv using metadata type lvm2`, dopodiché fallisce con:

    unexpected inconsistency; run fsck manually
    fsck exited with status code 4

e cade nella shell di `initramfs`.

Scegliendo il kernel più vecchio, usando la recovery mode, arrivo alla shell di ’initramfs’.

Provando a montare i volumi virtuali ext4 ottengo errori ma il fs viene montato:
    vgchange -ay

Provando vari comandi di ripristino ext4:
    fsck.ext4 -f -y -v -C0 /dev/sda
o
    fsck.ext4 -f -y -c /dev/sda

Comunque rimane l'errore "still have errors".

Si procede ad avviare il server tramite una chiavetta usb con l'installer di proxmox sopra.
Si tenterà di riparare il sistema com'è, prima di procedere a ripristinare i backup.

Avviato dall'USB, `fsck.ext4 -f -y -v -C0 /dev/pve/root` fallisce con:

    unable to set superblock flags on /dev/pve/root

Analisi di `dmesg` mostra errori hardware attivi su `ata2` / `sda`:

- `Medium Error` + `Unrecovered read error - auto reallocate failed` su più settori (77598976, 81793280, 111153408, 115347712, 115351808, 18952552)
- `hard resetting link` × 2
- `PHYRdychg` (instabilità connessione fisica)

**Conclusione: il disco fisico `/dev/sda` è in fase di guasto hardware.** I settori danneggiati non possono più essere rimappati. Qualsiasi tentativo di riparazione ulteriore rischia di peggiorare la situazione. La priorità è clonare il disco prima che peggiori.

## Avvio da USB — Scoperta e mount manuale dei volumi

Il sistema è avviato da una chiavetta USB bootable (installer Proxmox), quindi l'ambiente non ha visibilità automatica dei volumi del disco installato. Prima di qualsiasi operazione di diagnosi o riparazione è necessario scoprirli e montarli manualmente.

**Attivare i volumi LVM:**
```bash
# Scansiona i physical volume disponibili
pvscan

# Attiva tutti i volume group trovati
vgchange -ay

# Verifica i logical volume disponibili
lvs -a
```

**Montare il filesystem root di Proxmox:**
```bash
# Creare il punto di mount
mkdir -p /mnt/rescue

# Montare il root LV (adattare il path se il VG non si chiama 'pve')
mount /dev/pve/root /mnt/rescue

# Montare i filesystem secondari se necessario
mount /dev/sdaX /mnt/rescue/boot   # partizione boot (verificare con lsblk)
```

**Riferimento dispositivi:**
```bash
# Panoramica completa di dischi, partizioni e LV
lsblk -f
fdisk -l /dev/sda
```

Da questo punto in poi tutti i comandi di diagnosi e riparazione operano sui device `/dev/sda`, `/dev/pve/*` o sui path sotto `/mnt/rescue`.

## Salvataggio dati di configurazione

Il filesystem root è stato montato in sola lettura ignorando il journal:

```bash
mount -o ro,noload /dev/pve/root /mnt/rescue
```

La directory `/etc/pve/` risulta vuota perché in Proxmox non è una directory reale ma un filesystem FUSE (`pmxcfs`) montato a runtime dal demone `pve-cluster`. I dati reali si trovano nel database SQLite:

```bash
/mnt/rescue/var/lib/pve-cluster/config.db
```

Il file `config.db` contiene l'intero filesystem virtuale di `/etc/pve/`, inclusi:
- Configurazioni di tutte le VM (`qemu-server/*.conf`)
- Configurazioni di tutti i container LXC (`lxc/*.conf`)
- Utenti e permessi (`user.cfg`)
- Configurazione del datacenter (`datacenter.cfg`)
- Configurazione degli storage, incluso il volume di backup su NAS via SMB (`storage.cfg`)
- Regole firewall
- Configurazione di rete del nodo (`nodes/<hostname>/network`)

**File salvati sul disco di recupero:**

```bash
# Database principale pmxcfs — contiene tutto /etc/pve/
cp /mnt/rescue/var/lib/pve-cluster/config.db /mnt/recovery/

# Configurazione di rete dell'host (fuori da /etc/pve/)
cp /mnt/rescue/etc/network/interfaces /mnt/recovery/

# Hostname e risoluzione nomi
cp /mnt/rescue/etc/hostname /mnt/recovery/
cp /mnt/rescue/etc/hosts /mnt/recovery/

# Chiavi SSH root (accesso al nodo)
cp -r /mnt/rescue/root/.ssh /mnt/recovery/

# Configurazione backup vzdump (fuori da /etc/pve/)
cp /mnt/rescue/etc/vzdump.conf /mnt/recovery/

# Eventuali script o cron custom
cp -r /mnt/rescue/var/spool/cron/crontabs /mnt/recovery/
cp -r /mnt/rescue/etc/cron.d /mnt/recovery/
```

Per ispezionare il contenuto di `config.db` offline:

```bash
sqlite3 config.db "SELECT path FROM tree ORDER BY path;"
sqlite3 config.db "SELECT path, data FROM tree WHERE path LIKE '%storage%';"
```


## Piano di ripristino

### Step 1 — Estrazione configurazioni da config.db (offline, su altro PC)

Prima di reinstallare, estrarre i file di configurazione dal database salvato per averli come riferimento testuale:

```bash
# Elenco completo di tutti i file presenti nel DB
sqlite3 config.db "SELECT path FROM tree ORDER BY path;"

# Estrarre storage.cfg
sqlite3 config.db "SELECT data FROM tree WHERE path='storage.cfg';" > storage.cfg.txt

# Estrarre user.cfg (utenti, gruppi, permessi)
sqlite3 config.db "SELECT data FROM tree WHERE path='user.cfg';" > user.cfg.txt

# Estrarre datacenter.cfg (opzioni globali cluster)
sqlite3 config.db "SELECT data FROM tree WHERE path='datacenter.cfg';" > datacenter.cfg.txt

# Estrarre configurazioni VM (sostituire <vmid> con i valori reali)
sqlite3 config.db "SELECT path, data FROM tree WHERE path LIKE '%qemu-server%';" > vms.txt

# Estrarre configurazioni LXC
sqlite3 config.db "SELECT path, data FROM tree WHERE path LIKE '%lxc%';" > lxc.txt

# Estrarre configurazione rete del nodo
sqlite3 config.db "SELECT path, data FROM tree WHERE path LIKE '%network%';" > network.txt
```

### Step 2 — Reinstallazione Proxmox

- Installare Proxmox fresh sul nuovo disco
- Usare **lo stesso hostname** del vecchio nodo (verificabile da `/mnt/recovery/hostname`)
- Configurare la rete come da `/mnt/recovery/interfaces` e `network.txt`

### Step 3 — Riconfigurazione manuale da file estratti

**Storage** — riconfigurare da `storage.cfg.txt`:

Il file ha un formato semplice del tipo:
```
dir: local
        path /var/lib/vz
        content iso,vztmpl,backup

cifs: nas-backup
        path /mnt/pve/nas-backup
        server 192.168.x.x
        share <share_name>
        username <user>
        content backup
```
Ricreare ogni storage da GUI (Datacenter → Storage → Add) oppure scrivere direttamente `/etc/pve/storage.cfg` sul nuovo sistema.

**Utenti e permessi** — riconfigurare da `user.cfg.txt`:

Ricreare gli utenti da GUI (Datacenter → Permissions → Users) o editare `/etc/pve/user.cfg`.

**Opzioni datacenter** — riconfigurare da `datacenter.cfg.txt`:

Solitamente contiene keyboard layout, policy email, DNS. Riconfigurare da GUI (Datacenter → Options).

### Step 4 — Ripristino VM/CT dai backup NAS

Una volta ricollegato lo storage NAS:

```bash
# Da shell Proxmox — lista i backup disponibili
vzdump --list /mnt/pve/nas-backup/

# Ripristino da GUI: Datacenter → Storage NAS → Backups → Restore
# oppure da CLI:
qmrestore /mnt/pve/nas-backup/vzdump-qemu-<vmid>-*.vma.zst <vmid>
pct restore <vmid> /mnt/pve/nas-backup/vzdump-lxc-<vmid>-*.tar.zst
```

Ripristinare prima le VM/CT più critiche, verificare il funzionamento, poi procedere con le restanti.



