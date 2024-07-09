$(document).ready(function() {
    $('.import-select[name="path-hack"]').select2({
        width: "220px",
        ajax: { 
            contentType: 'application/json',
            dataType: 'json',
            delay: 500,
            url: function (params) {
                console.log(params.term);
                var part = ((params.term) ? params.term : '');
                return "/exist/restxq/nabu/collections"
                    + '?base=/db/apps/nabuCom/import'
                    + '&path=' + part
                },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                // since we are using custom formatting functions we do not need to alter remote JSON data
                return {results: data};
            }
        },
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 0,
        escapeMarkup: function (m) { return m; }
    });
    $('.import-select[name="path-hack"]').change(function() {
        var data = $('.import-select[name="path-hack"]').select2('data');
        fluxProcessor.sendValue("path", data[0].id);
    });
});


// request to close the form and switch back to view
function closeForm() {
    var doIt = confirm("Änderungen ungesichert - Trotzdem schließen?");
    if (doIt == false) {
        return;
    }
    $('#close-value').click();
}

