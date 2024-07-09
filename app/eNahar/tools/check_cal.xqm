xquery version "3.1";

let $c := collection("/db/apps/eNaharData/data/calendars/individuals")

let $cal :=
    $c/cal[owner/reference/@value="metis/practitioners/c-38496414-deca-4338-82e0-fd72afe5150f"]
return
    $cal
