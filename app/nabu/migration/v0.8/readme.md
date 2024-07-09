<p>
# Migration pre 0.8 Nabu data to FHIR 3.0.1

main tasks
:    1. move tickets from Order resource to FHIR Task
     2. move Appointments to Encounter with status 'planned'
     3. clean resource properties according to FHIR 3.0.1 XSD (needed for JSON serializing)
        - versionID -> versionId
        - Patient/communication language missing
        - some props type suffix missing e.g. abatement -> abatementDateTime
        - all extension elements
        
prerequisite
:    - nabu-0.8 package
steps
:    1. create dirs in nabuCom/data and nabuHistory/data (Careplans, ClinicalImpressions, Goals, Observations, Procedures, QuestionareResponses, Tasks)
     2. create dirs in nabuWorkflow/data (ActivityDefinitions, Library, PlanDefinitions, Protocols, Questionaires) 
     3. change all to 'spz' group with fix-perms.xql
     4. update collection.xconf for nabuCom 
     5. run scripts in migration/0.8
        - Patient
        - Encounter
        - Appointment
        - Task
        - Order
        - Communication
        - Composition
        - Condition
     6. update eNahar, metis, nabudocs
     7. check Task list, Kalendar

update to 0.8-26, run scripts in migration/0.8 with suffix 26 (status workflow, extension)
:    - Order
     - CarePlan
     - Composition
     - Encounter
</p>