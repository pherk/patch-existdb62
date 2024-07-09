$(document).ready(function() {
    $('.author-select[name="asserter-hack"]').select2({
        width: "220px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 3,
        ajax: { 
            url: "/exist/restxq/metis/PractitionerRole",
            contentType: 'application/json',
            dataType: 'json',
            delay: 500,
            data: function (params) {
                var part = params.term.split('#');
                return {
                    name: part[0], // search term
                    role: part[1],
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
    $('.asserter-select[name="asserter-hack"]').change(function() {
        var data = $('.asserter-select[name="asserter-hack"]').select2('data');
        fluxProcessor.sendValue("author-uid", data[0].id);
        fluxProcessor.sendValue("author-display", data[0].text);
    });
});