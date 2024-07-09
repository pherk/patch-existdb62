$(document).ready(function() {
    $('.order-select[name="due-hack"]').select2({
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
    $('.order-select[name="due-hack"]').change(function() {
        var data = $('.order-select[name="due-hack"]').select2('data');
        fluxProcessor.sendValue("due-display", data[0].text);
    });
});
