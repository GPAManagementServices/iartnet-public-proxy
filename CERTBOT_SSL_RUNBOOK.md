# Gestione Certificati SSL: Certbot & Nginx (Docker)

## 1. Il Meccanismo Architetturale (Webroot Challenge)
L'infrastruttura SSL è disaccoppiata e basata sul protocollo ACME (Let's Encrypt) utilizzando il plugin "webroot".

* **I Volumi Condivisi:** Esistono due volumi Docker fondamentali condivisi tra i container `iartnet_reverse_proxy` (Nginx) e `iartnet_certbot`:
  1. `certbot-webroot`: Usato per scambiare i file di sfida (challenge).
  2. `certbot-certs`: Usato per archiviare i certificati generati (`.pem`).
* **Il Flusso di Validazione:**
  1. Certbot contatta Let's Encrypt per richiedere un certificato per `dominio.it`.
  2. Let's Encrypt chiede di dimostrare il controllo del dominio creando un file specifico.
  3. Certbot crea questo file nel volume `certbot-webroot` (nella cartella `.well-known/acme-challenge/`).
  4. Let's Encrypt fa una richiesta HTTP sulla porta 80 a `http://dominio.it/.well-known/acme-challenge/...`
  5. Nginx intercetta questa specifica rotta e serve il file dal volume condiviso.
  6. Let's Encrypt convalida la risposta e invia a Certbot i certificati crittografici.
  7. Certbot salva i certificati nel volume `certbot-certs`, rendendoli immediatamente disponibili a Nginx per le configurazioni sulla porta 443 (HTTPS).

## 2. Automazione del Rinnovo tramite Crontab (Host Level)
I certificati Let's Encrypt scadono ogni 90 giorni. Certbot è programmato per rinnovarli solo quando mancano meno di 30 giorni alla scadenza.

Sebbene il container Certbot abbia un loop interno (`while :; do certbot renew; sleep 12h...`), Nginx carica i certificati in RAM all'avvio. Se Certbot rinnova un certificato sul disco, Nginx continuerà a servire quello vecchio finché non viene ricaricato. Per garantire un'automazione "zero-downtime", creiamo un task schedulato (Cronjob) sul sistema host Linux.

### Procedura di Attivazione Crontab

**Passo 1: Aprire l'editor di Cron per l'utente root**
Esegui sul terminale:
`sudo crontab -e`

**Passo 2: Inserire la direttiva di schedulazione**
Aggiungi la seguente riga alla fine del file per eseguire il controllo ogni giorno alle 03:00 del mattino:
`0 3 * * * docker exec iartnet_certbot certbot renew --quiet && docker exec iartnet_reverse_proxy nginx -s reload`

**Cosa fa questo comando atomico:**
1. `docker exec iartnet_certbot certbot renew --quiet`: Istruisce Certbot a controllare tutti i certificati. Rinnoverà *solo* quelli in scadenza nei prossimi 30 giorni. Il flag `--quiet` sopprime gli output non necessari.
2. `&&`: L'operatore logico assicura che il comando successivo venga eseguito solo se il primo termina senza errori.
3. `docker exec iartnet_reverse_proxy nginx -s reload`: Invia un segnale soft a Nginx per ricaricare la configurazione e i nuovi certificati in memoria, senza interrompere le connessioni attive degli utenti (Zero Downtime).

**Passo 3: Verifica**
Per verificare che il cronjob sia stato installato correttamente, esegui:
`sudo crontab -l`
