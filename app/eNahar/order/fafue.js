$(document).ready(function() {
    var subjectuid = $('#fafue-subject-value');
    
    $('.order-select[name="fafue-hack"]').select2({
        width: "240px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 0,
        ajax: { 
            url: function() {
                    return "/exist/restxq/nabu/patients/" + subjectuid.val() + "/responsibilities";
                },
            contentType: 'application/json',
            dataType: 'json',
            data: function (params) {
                return {
                    name: params.term // search term
                };
            },
        processResults: function (data, page) { // parse the results into the format expected by Select2.
            // since we are using custom formatting functions we do not need to alter remote JSON data
            return {results: data.data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.order-select[name="fafue-hack"]').change(function() {
        var data = $('.order-select[name="fafue-hack"]').select2('data');
        fluxProcessor.sendValue("fafue-uid", data[0].id);
        fluxProcessor.sendValue("fafue-display", data[0].text.split(' # ')[0]); // split "name # date"
    });
}); 