# Comandi utili

Guida rapida per le operazioni più comuni sui servizi Podman descritti in [Architettura](Architettura.md).
Tutti i comandi vanno eseguiti sulla macchina `ricotta` (o quella dove gira lo stack), dentro la cartella del servizio.

## Aggiornare l'immagine di un servizio

Esempio con Plex (cartella `ricotta/streaming`):

```
cd ricotta/streaming
podman-compose pull
systemctl --user restart 'podman-compose@streaming'
```

`podman-compose pull` scarica l'immagine aggiornata definita nel `podman-compose.yml`; il restart della unit systemd ricrea il container usando la nuova immagine (down + up), coerente con la gestione via systemd già in uso.

Se lo stack non è registrato come servizio systemd, basta:

```
cd ricotta/streaming
podman-compose pull
podman-compose up -d
```

### Non sei sicuro del nome della unit?

```
systemctl --user list-units 'podman-compose@*'
```

## Pulizia immagini vecchie

Dopo un aggiornamento, le immagini precedenti restano sul disco finché non vengono rimosse:

```
podman image prune -f
```

## Gestire uno stack registrato come servizio

```
# Avviare
systemctl --user start 'podman-compose@<nome>'

# Fermare
systemctl --user stop 'podman-compose@<nome>'

# Riavviare
systemctl --user restart 'podman-compose@<nome>'

# Stato
systemctl --user status 'podman-compose@<nome>'

# Log
journalctl --user -u 'podman-compose@<nome>'
```
