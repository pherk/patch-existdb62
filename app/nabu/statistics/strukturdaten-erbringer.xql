xquery version "3.1";

declare namespace fhir="http://hl7.org/fhir";
let $year := "2021"
let $encs := collection("/db/apps/nabuEncounter/data/" || $year)
let $ef := $encs/fhir:Encounter[fhir:status[@value='finished']]
let $sids := distinct-values(for $e in $ef/fhir:subject/fhir:reference/@value return substring-after($e,'nabu/patients/'))

return
<structurdaten year="{$year}">
    <termine>
        <gesamt>{count($ef)}</gesamt>
        <ärzte-allg>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-arzt']]])}</ärzte-allg>
        <ärzte-bont>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-bont']]])}</ärzte-bont>
        <ärzte-gbafg>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-gbafg']]])}</ärzte-gbafg>
        <ärzte-mmc>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-mmc']]])}</ärzte-mmc>
        <ärzte-moto>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-moto']]])}</ärzte-moto>
        <ärzte-nme>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-nme']]])}</ärzte-nme>
        <ärzte-ni>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-ni']]])}</ärzte-ni>
        <ärzte-psychsom>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-psychsom']]])}</ärzte-psychsom>
        <ärzte-regula>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-regula']]])}</ärzte-regula>
        <ärzte-nch>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-nch']]])}</ärzte-nch>
        <ärzte-ortho>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-ortho']]])}</ärzte-ortho>
        <psych>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-psych']]])}</psych>
        <psychDX>{count($ef/../fhir:Encounter[fhir:type[fhir:coding[fhir:code/@value='amb-spz-psychDX']]])}</psychDX>
        <psychdx>{count($ef/../fhir:Encounter[fhir:type[fhir:coding[fhir:code/@value='amb-spz-psychdx']]])}</psychdx>
        <psychber>{count($ef/../fhir:Encounter[fhir:type[fhir:coding[fhir:code/@value='amb-spz-psychber']]])}</psychber>
        <th-allg>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-th']]])}</th-allg>
        <th-physio>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-physio']]])}</th-physio>
        <th-logo>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-logo']]])}</th-logo>
        <th-ergo>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-ergo']]])}</th-ergo>
        <th-hp>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-heilp']]])}</th-hp>
        <eeg>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-eeg']]])}</eeg>
        <epnlg>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-epnlg']]])}</epnlg>
        <orthoptik>{count($ef/../fhir:Encounter[fhir:participant/fhir:type[fhir:coding[fhir:code/@value='spz-orthoptik']]])}</orthoptik>
    </termine>
</structurdaten>
