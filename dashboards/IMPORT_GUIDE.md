# Dashboard Import Guide

## Available Dashboards

### 1. Mikrotik Security Dashboard (`mikrotik-dashboard.ndjson`)

Dashboard dedicata al monitoraggio Mikrotik con:

- **Metriche**: Eventi totali, critici, login falliti, modifiche config
- **Timeline**: Eventi nel tempo per categoria
- **Analisi**: Top IP sorgente, Top utenti, distribuzione livelli
- **DHCP**: Tabella lease con MAC/IP/hostname
- **Security**: Tabella alert di sicurezza
- **Eventi**: Tabella dettagliata ultimi eventi

### 2. Log Explorer Dashboard (`log-explorer-dashboard.ndjson`)

Dashboard dinamica per esplorare tutti i log Wazuh con filtri interattivi:

- **Filtro per Agent**: Clicca su un agent per filtrare
- **Filtro per Rule Groups**: Tag cloud cliccabile per categoria
- **Filtro per Location/Source**: Tabella sorgenti cliccabile
- **Timeline**: Eventi per agent e per gruppo
- **Analisi**: Top regole, IP sorgente, distribuzione livelli
- **Tabella Eventi**: Dettaglio completo con tutti i campi

---

## Come Importare

### Metodo 1: Via Interfaccia Web

1. Accedi a **Wazuh Dashboard** (o OpenSearch Dashboards)
2. Vai su **Management** → **Stack Management** → **Saved Objects**
3. Clicca **Import**
4. Seleziona il file `.ndjson` da importare
5. Clicca **Import**
6. Se richiesto, seleziona "Automatically overwrite conflicts"

### Metodo 2: Via API (curl)

```bash
# Mikrotik Dashboard
curl -X POST "https://WAZUH_DASHBOARD:5601/api/saved_objects/_import?overwrite=true" \
  -H "osd-xsrf: true" \
  -H "Content-Type: multipart/form-data" \
  -u admin:admin \
  -F file=@mikrotik-dashboard.ndjson

# Log Explorer Dashboard  
curl -X POST "https://WAZUH_DASHBOARD:5601/api/saved_objects/_import?overwrite=true" \
  -H "osd-xsrf: true" \
  -H "Content-Type: multipart/form-data" \
  -u admin:admin \
  -F file=@log-explorer-dashboard.ndjson
```

### Metodo 3: Copia file direttamente

```bash
# Copia i file sul server Wazuh
scp dashboards/*.ndjson user@wazuh-server:/tmp/

# Sul server, importa via API
cd /tmp
curl -X POST "https://localhost:5601/api/saved_objects/_import?overwrite=true" \
  -H "osd-xsrf: true" \
  -H "Content-Type: multipart/form-data" \
  -u admin:admin \
  -k \
  -F file=@mikrotik-dashboard.ndjson
```

---

## Accesso alle Dashboard

Dopo l'import:

1. Vai su **Dashboard** nel menu laterale
2. Cerca "Mikrotik" o "Log Explorer"
3. Clicca sulla dashboard desiderata

---

## Uso della Log Explorer Dashboard

### Filtri Interattivi

La dashboard Log Explorer supporta **filtri dinamici**:

1. **Clicca su un Agent** nella tabella "Filter by Agent" → filtra per quell'agent
2. **Clicca su un Gruppo** nel tag cloud → filtra per quel rule.group  
3. **Clicca su una Location** nella tabella → filtra per quella sorgente

I filtri si sommano: puoi combinare agent + gruppo + location.

### Rimuovere Filtri

- Clicca sulla **X** accanto al filtro nella barra in alto
- Oppure clicca **Clear** per rimuovere tutti i filtri

### Cambiare Intervallo Temporale

- Usa il **time picker** in alto a destra
- Default: ultime 24 ore

---

## Personalizzazione

### Modificare una Visualizzazione

1. Clicca sull'icona **ingranaggio** sul pannello
2. Seleziona **Edit visualization**
3. Modifica query, aggregazioni, stile
4. Salva

### Aggiungere Pannelli

1. Clicca **Edit** sulla dashboard
2. Clicca **Add** → **Create new**
3. Crea nuova visualizzazione
4. Salva nella dashboard

---

## Troubleshooting

### "Index pattern not found"

L'index pattern `wazuh-alerts-*` deve esistere. Verifica:

1. **Management** → **Index Patterns**
2. Se non esiste, crealo con pattern `wazuh-alerts-*`

### Nessun dato visualizzato

1. Verifica che Wazuh stia ricevendo log
2. Controlla l'intervallo temporale (time picker)
3. Verifica i filtri attivi (rimuovili se necessario)

### Errore di import

Se l'import fallisce:

1. Prova ad importare con "Automatically overwrite conflicts"
2. Se persistono errori, elimina gli oggetti esistenti prima dell'import

---

## Query Utili

### Tutti gli eventi Mikrotik
```
rule.groups:mikrotik
```

### Eventi ad alta priorità
```
rule.level:>=10
```

### Eventi per agent specifico
```
agent.name:"nome-agent"
```

### Eventi per sorgente
```
location:"syslog-*"
```

### Combinazione filtri
```
rule.groups:mikrotik AND rule.level:>=8 AND agent.name:"mikrotik-router"
```
