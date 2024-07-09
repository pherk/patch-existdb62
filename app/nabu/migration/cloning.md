<?xml version="1.0" encoding="UTF-8"?>
<p>
# Clonen der DB

- sinnvoll zB für Testzwecke
- gelegentlich notwendig bei inkompatiblen eXistDB Updates
- entfernt alte packages aus repo

basics
:    0. backup old server (Achtung: backup files with umlauts not restorable)
     1. build new eXistdb (set proxy if needed)
     2. configure db (conf.xml, java options: memory, proxy)
     3. set admin password (restore demands a password)
steps
:    4. restore at least security of system dir if user accounts are important; admin will be overwritten, so you should know the admin password in backup
     5a. restore data collections, 
     5b. restore *.xconf files in system/config and reindex all (only if system/config was not restored)
     6. restore app packages or load new ones via package manager (imported packages first)
     7. fix permissions (nabu/temp/fix-perms.xql)
     8. repair app packages (nabu/temp/repair-after-backup.xql)
     9. check logs (exist, restxq)
     10. re-import missing files (mostly repo.xml for eXide, nabu, metis)
     10. remove small other glitches, reload restxq api functions
</p>