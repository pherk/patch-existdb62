$(document).ready(function() {
    $('.review-select[name="subject-hack"]').select2({
        width: "220px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 3,
        ajax: { 
            url: "/exist/restxq/nabu/patients",
            contentType: 'application/json',
            dataType: 'json',
            delay: 500,
            data: function (params) {
                var part = params.term.split('#');
                var ngs  = part[0].split(',');
                return {
                    name: ngs[0], // search term
                    given: ngs[1],
                    birthDate: part[1],
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
    $('.review-select[name="subject-hack"]').change(function() {
        var data = $('.review-select[name="subject-hack"]').select2('data');
        fluxProcessor.sendValue("subject-uid", data[0].id);
        fluxProcessor.sendValue("subject-display", data[0].text);
    });
});

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

// request to close the form and switch back to view
function closeForm() {
    var doIt = confirm("Änderungen ungesichert - Trotzdem schließen?");
    if (doIt == false) {
        return;
    }
    $('#close-value').click();
}

