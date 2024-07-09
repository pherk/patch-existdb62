$(document).ready(function() {
    var actoruid = $('#fafue-uid-value');
    var service  = $('#actor-service-value');
    
    $('.order-select[name="ownerservice-hack"]').select2({
        width: "180px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 0,
        ajax: { 
            url: function() {
                    return "/exist/restxq/enahar/services?owner=" + actoruid.val() + "&group=" + service.val();
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
    $('.order-select[name="ownerservice-hack"]').change(function() {
        var data = $('.order-select[name="ownerservice-hack"]').select2('data');
        fluxProcessor.sendValue("ownersched", data[0].id);
        fluxProcessor.sendValue("ownersched-display", data[0].text);
    });
}); 