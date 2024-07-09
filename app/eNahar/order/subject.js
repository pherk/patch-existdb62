$(document).ready(function() {
    $('.order-select[name="subject-hack"]').select2({
        width: "220px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 3,
        ajax: { 
            url: "/exist/restxq/nabu/patients",
            contentType: 'application/json',
            dataType: 'json',
            delay: 500,
            data: function (params) {
                var part = params.term.split('#');
                var ngs  = part[0].split(',');
                return {
                    name: ngs[0], // search term
                    given: ngs[1],
                    birthDate: part[1],
                    start: 1,
                    length: 20
                };
            },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                // since we are using custom formatting functions we do not need to alter remote JSON data
                return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.order-select[name="subject-hack"]').change(function() {
        var data = $('.order-select[name="subject-hack"]').select2('data');
        fluxProcessor.sendValue("subject-uid", data[0].id);
        fluxProcessor.sendValue("subject-display", data[0].text);
    });
});