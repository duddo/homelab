# Architettura

Questo documento dà una panoramica dell’hardware e software dell’Homelab.

## Hardware

Il sistema è composto da due computer fisici:
 - NAS Synology DS120J con disco Seagate BarraCuda 8 TB ST8000DM004
 - mini PC Firebat T8plus Intel N100, 16 GB, 512Gb

Amichevolmente chiamati `NAS` e `proxmox`, sul primo è installato il software di default Synology DSM 7.
Sul `promox` è installato il sistema operativo Proxmox. L’idea di base è che il `NAS` faccia da semplice storage 
e che tutti i servizi siano su VM o CT sul server.

## Networking

Indirizzi IP e macchine fisiche nella rete:

| Nome    | IP            | FQDN          |
|---------|---------------|---------------|
| NAS     | 192.168.1.100 | nas.local     |
| proxmox | 192.168.1.10  | proxmox.local |
| Router  | 192.168.1.1   | router.local  |

## DNS E DHCP

Gli FQDN `*.local` assegnati sono risolvibili solo all'interno della rete locale. Il server DNS che li risolve è
installato sul NAS. Per assicurarsi che tutte le macchine ottengano il DNS corretto, è stato disabilitato il DHCP 
server sul router e il NAS regge un suo DHCP server. Questo assegna gli indirizzi ip dando 192.168.1.100 come DNS primario.

## Macchine e servizi

Servizi esposti dalle macchine:

| Nome           | IP            | FQDN                | Descrizione                               |
|----------------|---------------|---------------------|-------------------------------------------|
| Proxmox        | 192.168.1.10  | proxmox.local       | Via http su 8006                          |
| NAS            | 192.168.1.100 | nas.local           | Via http su 5000                          |
| Receptaculum   | 192.168.1.30  | receptaculum.local  | CT, Debian, Docker, non accede al NAS     |
| Privileged     | 192.168.1.31  | privileged.local    | CT, Debian, Docker, accede al NAS         |
| Exit Node      | 192.168.1.40  | exitnode.local      | CT, Alpine, Tailscale, niente NAS         |
| Flaria         | 192.168.1.32  | flaria.local        | CT, Debian, Cloudflare tunnel, niente NAS |
| Home Assistant | 192.168.1.200 | homeassistant.local | VM, HAOS, dedicata a HA                   |

Tutte queste macchine accettano connessioni SSH solo tramite chiavi, salvate su 1Password.

## Storage e Backup

Lo storage è diviso in condivisioni Synology per poter regolare utenze d'accesso e quota. Sia la condivisione dati che
quella backup sono connesse a proxmox tramite NFS. Una condivisione Timemachine è usata per il solo backup del Mac.
Tutte le VM e CT sono periodicamente backuppate sul NAS da proxmox. Periodicamente viene manualmente connesso un disco
USB esterno al NAS, il quale tramite trigger automatico ci copia sopra i dati da proteggere.

## Docker

Tutti i servizi Docker sono attivati tramite Portainer (tranne Portainer stesso, avviato da CLI).
Per ogni servizio, esiste un file `.yml` in questo repository, dal quale Portainer attinge.
