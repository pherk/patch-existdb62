$(document).ready(function() {
    $('.review-select[name="actor-hack"]').select2({
        width: "160px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 0,
        ajax: { 
            url: "/exist/restxq/metis/PractitionerRole",
            contentType: 'application/json',
            dataType: 'json',
            delay: 300,
            data: function (params) {
                return {
                    name: params.term, // search term
                    role : $('.review-select[name="service-hack"]').val() || 'kikl-spz',
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
    $('.review-select[name="actor-hack"]').change(function() {
        var data = $('.review-select[name="actor-hack"]').select2('data');
        fluxProcessor.sendValue("actor-uid", data[0].id);
    });
});
