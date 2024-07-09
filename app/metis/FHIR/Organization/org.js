$(document).ready(function() {
    $(".org-select[name='org-ref-hack']").select2({
        width: "330px",
        placeholder: "bitte wählen",
        minimumInputLength: 3,
        ajax: { 
            url: "/exist/restxq/metis/organizations",
            contentType: 'application/json',
            dataType: 'json',
            delay: 300,
            data: function (params) {
                var part = params.term.split('#');
                return {
                    name: part[0], // search term
                    partOf: part[1], // search term
                    start: 1,
                    length: 15
                }
            },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                // since we are using custom formatting functions we do not need to alter remote JSON data
                return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $(".org-select[name='org-ref-hack']").change(function() {
        var data = $(".org-select[name='org-ref-hack']").select2('data');
        fluxProcessor.sendValue("org-ref",  "metis/organizations/" + data[0].id);
        fluxProcessor.sendValue("org-display", data[0].text);
    });
});