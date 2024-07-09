xquery version "3.1";

let $ofs := doc("/db/apps/nabuORBIS/OffeneFaelleBis30April2023.xml")/patients
return
<info>
    {$ofs/info[text()="Keine ORBIS PID"]}
    {$ofs/info[e/text()="Kein Besuch"]}
</info>