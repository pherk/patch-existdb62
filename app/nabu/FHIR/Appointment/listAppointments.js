$(document).ready(function () { 
        
    $('#openappointments tr').click(function (event) {
            if ($(this).attr('id')!='0') {
              window.location.href = "index.html?action=editAppointment&id="+$(this).attr('id'); //redirect to edit form         
            }
        });
    $.tablesorter.addParser({
            id: 'germandate',
            is: function(s) {
              return false;
            },
            format: function(s) {
                var a = s.split('-');
                a[1] = a[1].replace(/^[0]+/g,"");
                return new Date('20' + a.reverse().join("/")).getTime();
            },
            type: 'numeric'
        });

    $('#dp3').datepicker({
            format: 'D dd.M.yy',
            language: 'de'
        });
    $('#dp3').datepicker()
            .on('changeDate', function(e){ 
                console.log('changeDate');
        });
    
    $("#openappointments").tablesorter({theme:'blue',
                                    dateFormat : "yyyymmdd", // set the default date format
                                    widthFixed     : true,
                                    showProcessing : true,
                                    headerTemplate : '{content} {icon}',
                                    widgets:['zebra', 'filter'],
                                    widgetOptions : {
                                        filter_filteredRow : 'filtered',
                                        // Add select box to 0th column (zero-based index) 
                                        // each option has an associated function that returns a boolean 
                                        // function variables: 
                                        // e = exact text from cell 
                                        // n = normalized value returned by the column parser 
                                        // f = search filter input value 
                                        // i = column index 
                                        filter_functions: null,
                                        // {
                                                    // Add these options to the select dropdown (numerical comparison example)
                                                    // Note that only the normalized (n) value will contain numerical data
                                                    // If you use the exact text, you'll need to parse it (parseFloat or parseInt)
                                        //    0 : {
                                        //          "heute"      : function(e, n, f, i, $r) { return n = "16-11-2014"; }
                                        // }},
                                        scroller_height : 500, scroller_barWidth : 17, scroller_jumpToHeader:false, scroller_idPrefix : 's_'
                                    },                                    
                                    sortList:[[0,1]],
                                    headers: {0:{sorter: 'germandate'},    //   "shortDate", dateFormat: "yyyymmdd"},
                                              1:{sorter: 'time'}}
        });
});