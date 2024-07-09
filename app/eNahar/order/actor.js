$(document).ready(function() {
    $('.order-select[name="actor-hack"]').select2({
        width: "160px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 0,
        ajax: { 
            url: "/exist/restxq/metis/PractitionerRole",
            contentType: 'application/json',
            dataType: 'json',
            delay: 300,
            allowClear : true,
            data: function (params) {
                return {
                      name: params.term // search term
                    , role : function() {
                            return $('.order-select[name="service-hack"]').val() || 'kikl-spz';
                    }
                    , start: 1
                    , length: '*'
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
    $('.order-select[name="actor-hack"]').change(function() {
        var data = $('.order-select[name="actor-hack"]').select2('data');
        fluxProcessor.sendValue("actor-uid", data[0].id);
        fluxProcessor.sendValue("actor-display", data[0].text);
        $('#calendar').fullCalendar( 'refetchEvents' );
    });
});