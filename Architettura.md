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

| Nome    | IP            | FQDN                    |
|---------|---------------|-------------------------|
| NAS     | 192.168.1.100 | nas.casa.totaro.net     |
| proxmox | 192.168.1.10  | proxmox.casa.totaro.net |
| Router  | 192.168.1.1   | router.casa.totaro.net  |

## DNS E DHCP

Gli FQDN `*.casa.totaro.net` risolvono solo IP locali. Il server DNS che li risolve è Cloudflare, su dominio proprietario.
Prcedentemente gli indirizzi erano `*.local`, risolti tramite server DNS su NAS. Lo stesso nas faceva da DHCP server.
Questo assegnava gli indirizzi ip dando 192.168.1.100 come DNS primario.
Per semplificare l'architettura di rete, ci si affida adesso al DNS pubblico di Cloudflare.

## Macchine e servizi

Servizi esposti dalle macchine:

| Nome           | IP            | FQDN                          | Descrizione                               |
|----------------|---------------|-------------------------------|-------------------------------------------|
| Proxmox        | 192.168.1.10  | proxmox.casa.totaro.net       | Via http su 8006                          |
| NAS            | 192.168.1.100 | nas.casa.totaro.net           | Via http su 5000                          |
| Receptaculum   | 192.168.1.30  | receptaculum.casa.totaro.net  | CT, Debian, Docker, non accede al NAS     |
| Privileged     | 192.168.1.31  | privileged.casa.totaro.net    | CT, Debian, Docker, accede al NAS         |
| Exit Node      | 192.168.1.40  | exitnode.casa.totaro.net      | CT, Alpine, Tailscale, niente NAS         |
| Flaria         | 192.168.1.32  | flaria.casa.totaro.net        | CT, Debian, Cloudflare tunnel, niente NAS |
| Home Assistant | 192.168.1.200 | homeassistant.casa.totaro.net | VM, HAOS, dedicata a HA                   |

Tutte queste macchine accettano connessioni SSH solo tramite chiavi, salvate su 1Password.

## Storage e Backup

Lo storage è diviso in condivisioni Synology per poter regolare utenze d'accesso e quota. Sia la condivisione dati che
quella backup sono connesse a proxmox tramite SMB. Una condivisione Timemachine è usata per il solo backup del Mac.
Tutte le VM e CT sono periodicamente backuppate sul NAS da proxmox. Periodicamente viene manualmente connesso un disco
USB esterno al NAS, il quale tramite trigger automatico ci copia sopra i dati da proteggere.

## Docker

Tutti i servizi Docker sono attivati tramite Portainer (tranne Portainer stesso, avviato da CLI).
Per ogni servizio, esiste un file `.yml` in questo repository, dal quale Portainer attinge.
