# Handoff – aktueller Fehler – 2026-08-29

## Aktueller Zustand

Die laufende Manifold-Instanz im LXC ist derzeit nicht funktionsfähig.

Beim Aufruf der Oberfläche unter `http://192.168.51.19:13100` erscheint aktuell:

```text
We're at a bit of a loose end.
Frightfully sorry.

503 Error: API TypeError
```

Zuvor war die Oberfläche erreichbar, aber der Login reagierte auf Klicks überhaupt nicht. In den Server-Logs erschien beim Klick kein Login-/Auth-Request; sichtbar waren nur die regelmäßigen `/api/up`-Healthchecks.

## Verifizierte Beobachtungen

- `browser.config.js` wurde erfolgreich ausgeliefert.
- Das Browser-JavaScript-Bundle wurde mit HTTP 200 ausgeliefert.
- `browser.config.js` wurde im HTML vor dem Haupt-JavaScript-Bundle geladen.
- Der API-Healthcheck `/api/up` lieferte zeitweise HTTP 200.
- Der Client war intern erreichbar und lieferte zeitweise extern HTTP 200.
- Trotz erreichbarer Seite erzeugte ein Klick auf Login keinen Request an API/Proxy.
- Nach weiteren Runtime-/Proxy-Konfigurationsänderungen zeigt die Oberfläche nun den oben genannten `503 Error: API TypeError`.

## Offiziell verifizierte Produktionsarchitektur

Das aktuelle offizielle `ManifoldScholar/manifold-deploy-example` verwendet in Produktion einen gemeinsamen öffentlichen Ursprung. Der Reverse Proxy routet:

```text
/api/*  -> Rails API auf Port 3011
alles andere -> Client/SSR auf Port 3010
```

Die offizielle Produktionskonfiguration setzt dabei `CLIENT_URL`, `CLIENT_BROWSER_API_URL` und `CLIENT_BROWSER_API_CABLE_URL` auf denselben öffentlichen Ursprung; `CLIENT_SERVER_API_URL` zeigt intern direkt auf die Rails-API.

## Offene Ursache

Die konkrete Ursache des aktuellen `503 Error: API TypeError` ist noch nicht ermittelt.

Es darf nicht weiter auf Verdacht an Runtime-, Proxy-, Client-, API- oder Source-Konfiguration geändert werden. Der nächste Schritt muss ausschließlich eine belegte Diagnose des aktuellen Fehlers sein.
