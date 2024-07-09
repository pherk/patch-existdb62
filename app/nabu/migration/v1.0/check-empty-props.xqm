xquery version "3.1";

declare namespace fhir   = "http://hl7.org/fhir";

let $c :=collection("/db/apps/nabuCom/data/Communications")

return
    distinct-values(for $p in $c/fhir:Communication/*[not(*) and not(@*)] return local-name($p))