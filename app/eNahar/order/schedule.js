$(document).ready(function() {
    var actoruid = $('#fafue-uid-value');
    var service  = $('#actor-service-value');
    
    $('.order-select[name="schedule-hack"]').select2({
        width: "180px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 0,
        ajax: { 
            url: function() {
                    return "/exist/restxq/enahar/schedules";
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
            return {results: data};
            }
        },
        tags : true,
  createTag: function (params) {
    return {
      id: ':missing',
      text: ':missing',
      newOption: true
    }
  },
        escapeMarkup: function (m) { return m; }
    });
    $('.order-select[name="schedule-hack"]').change(function() {
        var data = $('.order-select[name="schedule-hack"]').select2('data');
        fluxProcessor.sendValue("schedule-uid", data[0].id);
        fluxProcessor.sendValue("schedule-display", data[0].text);
    });
}); 