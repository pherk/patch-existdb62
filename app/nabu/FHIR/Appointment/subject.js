$(document).ready(function() {
    $('.app-select[name="subject-hack"]').select2({
        width: "220px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 3,
        ajax: { 
            url: "/exist/restxq/nabu/patients",
            contentType: 'application/json',
            dataType: 'json',
            delay: 300,
            data: function (params) {
                var part = params.term.split('#');
                return {
                    name: part[0], // search term
                    birthDate: part[1],
                    start: 1,
                    length: 10
                };
            },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                // since we are using custom formatting functions we do not need to alter remote JSON data
                return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.app-select[name="subject-hack"]').change(function() {
        var data = $('.app-select[name="subject-hack"]').select2('data');
        fluxProcessor.sendValue("subject-id", data[0].id);
    //    fluxProcessor.sendValue("subject-display", data[0].text);
    });
});