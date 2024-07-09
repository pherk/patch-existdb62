$(document).ready(function() {
    $('.app-select[name="service-hack"]').select2({
        width: "160px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 0,
        ajax: { 
            url: "/exist/restxq/metis/roles?filter=service",
            contentType: 'application/json',
            dataType: 'json',
            delay: 300,
            data: function (params) {
                return {
                    name: params.term, // search term
                    start: 1,
                    length: '*'
                };
            },
        processResults: function (data, page) { // parse the results into the format expected by Select2.
            // since we are using custom formatting functions we do not need to alter remote JSON data
            return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.app-select[name="service-hack"]').change(function() {
        var data = $('.app-select[name="service-hack"]').select2('data');
        fluxProcessor.sendValue("app-group", data[0].id);
    //  fluxProcessor.sendValue("service-display", data[0].text);
    });
});