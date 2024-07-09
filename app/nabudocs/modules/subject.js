$(document).ready(function() {
    var demobdate = $('#demo-bdate');
    var demobdateinput = $('#demo-bdate-input');
    var active = $('#merge-active');
    $('.patient-select[name="subject1-hack"]').select2({
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
                    active: function(){ 
                        return active.val() },
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
    $('.patient-select[name="subject1-hack"]').change(function() {
        var data = $('.patient-select[name="subject1-hack"]').select2('data');
        fluxProcessor.sendValue("subject1-uid", data[0].id);
        fluxProcessor.sendValue("subject1-display", data[0].text);
    });
    $('.patient-select[name="subject2-hack"]').select2({
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
    $('.patient-select[name="subject2-hack"]').change(function() {
        var data = $('.patient-select[name="subject2-hack"]').select2('data');
        fluxProcessor.sendValue("subject2-uid", data[0].id);
        fluxProcessor.sendValue("subject2-display", data[0].text);
    });
});

function removeSuperfluousRepeatIndex() {
    console.log($('#r-orders-id > tbody'));
    $('#r-orders-id > tbody > tr').each(function(){
        $this = $(this);
        $this.attr("class","xfReadWrite xfOptional xfValid xfRepeatItem xfEnabled");
        console.log($this);
    });
//    $('#r-orders-id > tbody > tr').attr("class","xfReadWrite xfOptional xfValid xfRepeatItem xfEnabled xfRepeatIndex");
    console.log($('#r-orders-id > tbody > tr'));
}

// request to close the form and switch back to view
function setBirthDate() {
    $('#demo-bdate').datepicker('update', $('#bdate-value').val());
//    console.log("setting birthDate: " +   $('#bdate-value').val());
    $('#demo-bdate').datepicker().on('changeDate', function(e) {
        fluxProcessor.sendValue("bdate", $('#demo-bdate').datepicker('getFormattedDate'));
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
