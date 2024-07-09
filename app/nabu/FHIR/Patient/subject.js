$(document).ready(function() {
//    var demobdate = $('#demo-bdate');
//    var demobdateinput = $('#demo-bdate-input');
//    var subjectuid = $('#fafue-subject-value');
//    var actoruid = $('#fafue-uid-value');
//    var service  = $('#actor-service-value');
    
    $('.patient-select[name="subject-hack"]').select2({
        width: "220px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 4,
        ajax: { 
            url: "/exist/restxq/nabu/patients",
            contentType: 'application/json',
            dataType: 'json',
            delay: 500,
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
    $('.patient-select[name="subject-hack"]').change(function() {
        var data = $('.patient-select[name="subject-hack"]').select2('data');
        fluxProcessor.sendValue("subject-uid", data[0].id);
        fluxProcessor.sendValue("subject-display", data[0].text);
    });

});

function setSelectFocus() {
    console.log('set focus');
    $('.patient-select[name="subject-hack"]').select2('open');
}
// request to close the form and switch back to view
function setBirthDate() {
    $('#demo-bdate').datepicker('update', $('#bdate-value').val());
//    console.log("setting birthDate: " +   $('#bdate-value').val());
    $('#demo-bdate').datepicker().on('changeDate', function(e) {
//        fluxProcessor.sendValue("bdate", $('#demo-bdate').datepicker('getFormattedDate'));
          fluxProcessor.sendValue("bdate",$('#demo-bdate').data('datepicker').getFormattedDate('yyyy-mm-dd')); 
//        console.log( $('#demo-bdate').data('datepicker').getFormattedDate('yyyy-mm-dd'));
    });
    $('#demo-bdate-input').change(function() {
//            console.log('on changeDate')            
        })
}

function initICD() {
    $('.patient-select[name="icd10-hack"]').select2({
        width: "420px",
        placeholder: "Code oder Text eingeben",
        allowClear: true,
        minimumInputLength: 1,
        ajax: { 
            url: "/exist/restxq/terminology/icd10",
            contentType: 'application/json',
            dataType: 'json',
            delay: 500,
            data: function (params) {
                var term = params.term;
                var regex = /[.*\[\]]/;
                var reicd = /[A-TV-Z]\d[0-9AB](?:\.([\dA-KXZ][\dAX-Z][\dX][0-59A-HJKMNP-S]|[\dA-KXZ][\dAX-Z][\dX]|[\dA-KXZ][\dAX-Z]|[\dA-KXZ]))?/;
                var isRegex = term.length < 3 || regex.test(term);
                var isICD10 = reicd.test(term);
                var out;
                if (isRegex){
                    out = {
                        search: term, // search term
                        scope : 'code',
                        type : 'regex',
                        start: 1,
                        length: 20
                    };
                }
                else if (isICD10) {
                    out = {
                        search: term, // search term
                        scope : 'code',
                        start: 1,
                        length: 20
                    };
                }
                else { 
                    out = {
                        search: term.toLowerCase(), // search term
                        scope : 'description',
                        start: 1,
                        length: 20
                    };
                };
                console.log(out);
                return out;
            },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                // since we are using custom formatting functions we do not need to alter remote JSON data
                return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.patient-select[name="icd10-hack"]').change(function() {
        var data = $('.patient-select[name="icd10-hack"]').select2('data');
        fluxProcessor.sendValue("icd10-code", data[0].id);
        fluxProcessor.sendValue("icd10-text", data[0].textonly);
    });
}
function initHPO() {
    $('.patient-select[name="hpo-hack"]').select2({
        width: "420px",
        placeholder: "Code oder Text eingeben",
        allowClear: true,
        minimumInputLength: 1,
        ajax: { 
            url: "/exist/restxq/terminology/hpo",
            contentType: 'application/json',
            dataType: 'json',
            delay: 500,
            data: function (params) {
                var term = params.term;
                var regex = /[.*\[\]]/;
                var redigit = /\d/;
                var isRegex = term.length < 6 || regex.test(term);
                var isDigit = redigit.test(term);
                var out;
                if (isRegex){
                    out = {
                        search: term, // search term
                        scope : 'code',
                        type : 'regex',
                        start: 1,
                        length: 20
                    };
                }
                else if (isDigit) {
                    out = {
                        search: term, // search term
                        scope : 'code',
                        start: 1,
                        length: 20
                    };
                }
                else { 
                    out = {
                        search: term.toLowerCase(), // search term
                        scope : 'description',
                        start: 1,
                        length: 20
                    };
                };
                console.log(out);
                return out;
            },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                // since we are using custom formatting functions we do not need to alter remote JSON data
                return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.patient-select[name="hpo-hack"]').change(function() {
        var data = $('.patient-select[name="hpo-hack"]').select2('data');
        fluxProcessor.sendValue("hpo-code", data[0].id);
        fluxProcessor.sendValue("hpo-text", data[0].textonly);
    });
}
function initOrphanet() {
    $('.patient-select[name="orphanet-hack"]').select2({
        width: "420px",
        placeholder: "Code oder Text eingeben, english, min 6 chars",
        allowClear: true,
        minimumInputLength: 6,
        ajax: { 
            url: "/exist/restxq/terminology/orphanet",
            contentType: 'application/json',
            dataType: 'json',
            delay: 500,
            data: function (params) {
                var term = params.term;
                var regex = /[.*\[\]]/;
                var redigit = /\d/;
                var isRegex = term.length < 6 || regex.test(term);
                var isDigit = redigit.test(term);
                var out;
                if (isRegex){
                    out = {
                        search: term, // search term
                        scope : 'code',
                        type : 'regex',
                        start: 1,
                        length: 20
                    };
                }
                else if (isDigit) {
                    out = {
                        search: term, // search term
                        scope : 'code',
                        start: 1,
                        length: 20
                    };
                }
                else { 
                    out = {
                        search: term.toLowerCase(), // search term
                        scope : 'description',
                        start: 1,
                        length: 20
                    };
                };
                console.log(out);
                return out;
            },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                // since we are using custom formatting functions we do not need to alter remote JSON data
                return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.patient-select[name="orphanet-hack"]').change(function() {
        var data = $('.patient-select[name="orphanet-hack"]').select2('data');
        fluxProcessor.sendValue("orphanet-code", data[0].id);
        fluxProcessor.sendValue("orphanet-text", data[0].textonly);
    });
}

function initFaFue() {
    $('.order-select[name="fafue-hack"]').select2({
        width: "240px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 0,
        ajax: { 
            url: "/exist/restxq/nabu/patients/" + $('#fafue-subject-value').val() + "/responsibilities",
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
//        fluxProcessor.sendValue("fafue-display", data[0].text.split(' # ')[0]); // split "name # date"
    });
}

function initSchedule() {
    $('.order-select[name="schedule-hack"]').select2({
        width: "180px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 0,
        ajax: { 
            url: "/exist/restxq/enahar/services",
            contentType: 'application/json',
            dataType: 'json',
            data: function (params) {
                return {
                    owner : function() { return $('#fafue-uid-value').val() },
                    group : function() { return $('#actor-service-value').val() },
                    name  : params.term // search term
                };
            },
        processResults: function (data, page) { // parse the results into the format expected by Select2.
            // since we are using custom formatting functions we do not need to alter remote JSON data
            return {results: data.data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.order-select[name="schedule-hack"]').change(function() {
        var data = $('.order-select[name="schedule-hack"]').select2('data');
        fluxProcessor.sendValue("schedule", data[0].id);
        fluxProcessor.sendValue("schedule-display", data[0].text);
    });
}

function setOnsetDateTime() {
    $('#cond-onset').datepicker('update', $('#onset-value').val());
//    console.log("setting onset date: " +   $('#onset-value').val());
    $('#cond-onset').datepicker().on('changeDate', function(e) {
        fluxProcessor.sendValue("onset", $('#cond-onset').data('datepicker').getFormattedDate('yyyy-mm-dd'));
//        console.log("date sended")
    });
    $('#cond-onset-input').change(function() {
//            console.log('on changeDate')            
        })
}

function setAbatementDateTime() {
    $('#cond-abatement').datepicker('update', $('#abatement-value').val());
//    console.log("setting abatement date: " +   $('#abatement-value').val());
    $('#cond-abatement').datepicker().on('changeDate', function(e) {
        fluxProcessor.sendValue("abatement", $('#cond-abatement').data('datepicker').getFormattedDate('yyyy-mm-dd'));
//        console.log("date sended")
    });
    $('#demo-bdate-input').change(function() {
//            console.log('on changeDate')            
        })
}


// request to close the form and switch back to view
function closeForm() {
    var doIt = confirm("Änderungen ungesichert - Trotzdem schließen?");
    if (doIt == false) {
        return;
    }
    $('#close-value').click();
}

