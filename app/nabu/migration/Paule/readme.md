steps to import PAULE data
1:  export all tables to separate XML files (MS-Access) 
1a: edit Arzt.xml (aka contacts) to match super tag (jedit) 
1b: edit Abk_Erbringer.xml (aka users) to match user identifier/alias (jedit)
1c: edit Datum.xml, discard T00:00:00 from I_Datum
1d: edit T_WartelisteNeu.xml, change TerminArt fields to group names

from import dir:
2:  run contacts.xql (never, since already transferred to Metis)
3:  run patient2fhir.xql (patients);  ~4 for 25.000 demographics
4:  run termine2fhir.xql (appointments/encounters); be patient ~40min for 100.000 events
5.  run warteliste2fhir.xql (Orders)
6.  run sondertermine2fhir.xql (never, since Paule stopped 31.12.2105)
7.  run absent2fhir.xql (never, since already transferred to Metis)

notes on contacts
- entries get old category tag from PAULE plus "invalid"; these should be removed on validation
- entries get a KA_Nr id to allow cross import for patients; can be removed later

notes on patient demographics
- id gets old PAULENR