$(document).ready(function() {
    var rolehack = $('.task-select[name="role-hack"]');
    var targethack = $('.task-select[name="target-hack"]');
                 
    $('.task-select[name="subject-hack"]').select2({
        width: "330px",
        placeholder: "bitte wählen",
        minimumInputLength: 3,
        ajax: { 
            url: "/exist/restxq/nabu/patients",
            contentType: 'application/json',
            dataType: 'json',
            delay : 500,
            data: function (params) {
                var part = params.term.split('#');
                var ngs  = part[0].split(',');
                var backslash = ngs[0].indexOf("\\")
                var colon = ngs[0].indexOf(":")
                var family = ngs[0].substr(backslash + 1)
                var pid = ngs[0].substr(colon + 1)
                return {
                    name: (colon<0 ? family : undefined), // search term
                    given: ngs[1],
                    birthDate: part[1],
                    use : (backslash<0 ? 'official' : 'old'),
                    pid : (colon<0 ? undefined : pid),
                    active : 'true',
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
    $('.task-select[name="role-hack"]').select2({
            width: "220px",
            placeholder: "bitte wählen",
            minimumInputLength: 0,
            ajax: { 
                url: "/exist/restxq/metis/roles",
                dataType: 'json',
                data: function (params) {
                    return {
                        name: params.term, // search term
                        filter: '*',
                        start: '1',
                        length: '*'
                    }
                },
                processResults: function (data, page) { // parse the results into the format expected by Select2.
                    // since we are using custom formatting functions we do not need to alter remote JSON data
                    return {results: data};
                }
            },
            escapeMarkup: function (m) { return m; }
        });
    $('.task-select[name="target-hack"]').select2({
            width: "220px",
            placeholder: "bitte wählen",
            minimumInputLength: 0,
            ajax: { 
                url: "/exist/restxq/metis/PractitionerRole",
                contentType: 'application/json',
                dataType: 'json',
                data: function (params) {
                    var theID = rolehack.select2('data')[0].id;
                    return {
                        "name": params.term, // search term
                        "start": "1",
                        "length": "*",
                        "role": theID
                    }
                },
                processResults: function (data, page) { // parse the results into the format expected by Select2.
                    // since we are using custom formatting functions we do not need to alter remote JSON data
                    return {results: data};
                }
            },
            escapeMarkup: function (m) { return m; }
    });
    $('.task-select[name="subject-hack"]').change(function() {
        var data = $('.task-select[name="subject-hack"]').select2('data');
        fluxProcessor.sendValue("subject-ref",  "nabu/patients/" + data[0].id);
        fluxProcessor.sendValue("subject-display", data[0].text);
    });
    $('.task-select[name="role-hack"]').change(function() {
        var data = rolehack.select2('data');
        fluxProcessor.sendValue("target-role", data[0].id);
    });
    $('.task-select[name="target-hack"]').change(function() {
        var data = targethack.select2('data');
        fluxProcessor.sendValue("target-ref",  "metis/practitioners/" + data[0].id);
        fluxProcessor.sendValue("target-display", data[0].text);
    });
});