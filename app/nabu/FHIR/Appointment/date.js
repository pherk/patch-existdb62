$(document).ready(function() {
    $('.app-select[name="date-hack"]').select2({
        width: "160px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 1,
        ajax: { 
            url: "/exist/restxq/enahar/d2d",
            contentType: 'application/json',
            dataType: 'json',
            delay: 300,
            data: function (params) {
                return {
                    date: params.term, // search term
                };
            },
        processResults: function (data, page) { // parse the results into the format expected by Select2.
            // since we are using custom formatting functions we do not need to alter remote JSON data
            return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.app-select[name="date-hack"]').change(function() {
        var data = $('.app-select[name="date-hack"]').select2('data');
        fluxProcessor.sendValue("app-date", data[0].text);
    });
});
