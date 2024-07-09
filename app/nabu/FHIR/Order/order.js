$(document).ready(function() {
    var rolehack = $('.order-select[name="role-hack"]');
    var targethack = $('.order-select[name="target-hack"]');
                 
    $('.order-select[name="subject-hack"]').select2({
        width: "220px",
        placeholder: "bitte wählen",
        minimumInputLength: 2,
        ajax: { 
            url: "/exist/restxq/nabu/patients",
            contentType: 'application/json',
            dataType: 'json',
            delay : 300,
            data: function (params) {
                var part = params.term.split('#');
                return {
                    name: part[0], // search term
                    birthDate : part[1],
                    start: '1',
                    length: '15'
                };
            },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                    // since we are using custom formatting functions we do not need to alter remote JSON data
                        return {results: data};
                }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.order-select[name="role-hack"]').select2({
        width: "220px",
        placeholder: "bitte wählen",
        minimumInputLength: 0,
        ajax: { 
            url: "/exist/restxq/metis/roles",
            dataType: 'json',
            data: function (term, page) {
                return {
                    name: term, // search term
                        start: 1,
                        length: 10,
                    };
            },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                    // since we are using custom formatting functions we do not need to alter remote JSON data
                        return {results: data};
                }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.order-select[name="target-hack"]').select2({
        width: "220px",
        placeholder: "bitte wählen",
        minimumInputLength: 0,
        ajax: { 
            url: "/exist/restxq/metis/users",
            dataType: 'json',
            data: function (term, page) {
                return {
                    name: term, // search term
                    start: 1,
                    length: 10,
                    role: $('.order-select[name="role-hack"]').select2('data').id
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
        fluxProcessor.sendValue("subject-ref",  "nabu/patients/" + data[0].id);
        fluxProcessor.sendValue("subject-display", data[0].text);
    });
    $('.order-select[name="role-hack"]').change(function() {
        var data = rolehack.select2('data');
        fluxProcessor.sendValue("target-role", data[0].id);
    });
    $('.order-select[name="target-hack"]').change(function() {
        var data = targethack.select2('data');
        fluxProcessor.sendValue("target-ref",  "metis/practitioners/" + data[0].id);
        fluxProcessor.sendValue("target-display", data[0].text);
    });
});