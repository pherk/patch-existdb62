$(document).ready(function() {
    $(".comm-select[name='subject-hack']").select2({
        width: "220px",
        placeholder: "bitte wählen",
        minimumInputLength: 3,
        ajax: { 
            url: "/exist/restxq/nabu/patients",
            dataType: 'json',
            data: function (params) {
                return {
                    name: params.term, // search term
                    start: 1,
                    length: 10,
                };
            },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                // since we are using custom formatting functions we do not need to alter remote JSON data
                return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $(".comm-select[name='subject-hack']").change(function() {
        var data = $(".comm-select[name='subject-hack']").select2('data');
        fluxProcessor.sendValue("subject-ref", "nabu/patients/" + data[0].id);
        fluxProcessor.sendValue("subject-display", data[0].text);
    });
});