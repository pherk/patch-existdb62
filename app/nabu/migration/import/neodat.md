<?xml version="1.0" encoding="UTF-8"?>
<p>
# FG Nachsorge nach GBA

Basis-Daten
:    - SSW Woche; Tag
     - Geb.Gew.
     - Geb.Datum
     - Entlassdatum
     - Mehrling
Optionale Daten
:    - Diagnosen aus dem Entlassbrief
     - div Parameter, die in Neodat sind: Hirnblutung, Grad, usw (NeoDat-Import?)

Aufnahme von Nicht-SPZ-Kindern, die hier in der Neonatologie waren, wegen des Reporting erforderlich (incl. Verstorbene)

# Bayley III

Wunsch-Test-Datum
:    - 2J +m (40w - SSW;Tag)
     - Arzttermin sein, am besten gekoppelt

Pflichtdaten
:    - Test stattgefunden
     - KL, KU, KG
     - blind, schwerhörig
     - schwere motorische Retardierung
     - schwere mentale Ret. (Cog&lt;1/55)
     - keine oder geringfügige mentale Retardierung (Cog=4/70)
     
die letzten beiden könnte man auch errechnen, wenn wir die Testergebnisse protokollieren. allerdings gehören zru schweren ment. Ret auch die die nicht testbar sind, deshalb sollte das auch so angebbar sein

# NeoNachsorge Workflow in Nabu

**Patienten-bezogen**  
1. Patienten anlegen (erfolgt i.d.R. bereits während des Entlassmanagement)
2. Neonatal-Daten eingeben (s.o.; erfolgt sonst automat. beim späteren NeoDat-Import)
3. CarePlan für Neo-Nachsorge anlegen und Termine generieren (erfolgt sonst automat. beim späteren NeoDat-Import)

**Review GBA-Nachsorge**  
1. Basis-Daten auf Vollständigkeit prüfen, gfls. ergänzen oder NeoDat-Import durchführen
2. CarePlan aktualisieren bzw. Actions triggern
3. Deadlines für 2-Jahrestermin checken; Termin anmahnen, Ablehnung dokumentieren ('lost'), gfls. externe Daten einpflegen
4. Statistik und Report generieren
</p>