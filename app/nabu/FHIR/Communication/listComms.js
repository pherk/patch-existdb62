$(document).ready(function () {      
    $('#comms tr').on('click', function (event) {
        if (event.ctrlKey && $(this).attr('id')!='0') {
          window.location.href = "/exist/restxq/nabu/communications2pdf"
                        +'?rangeStart=2015-01-01T08:00:00'
                        +'&rangeEnd=2021-04-01T08:00:00'
                        +'&id=' + $(this).attr('id')
                        +'&status=in-progress'
                        +'&status=enroll'
                        +'&printed=false'; //print status update         
        }
    });
});
    $(function() {
        $("#comms").tablesorter({theme:'blue',
                dateFormat : "yyyymmdd", // set the default date format
                widthFixed     : true,
                showProcessing : true,
                headerTemplate : '{content} {icon}',
                widgets:['zebra', 'filter', 'scroller'],
                widgetOptions : {
                    filter_defaultAttrib : 'data-value',
                    filter_searchDelay : 300,
                    filter_startsWith  : false,
                    // Add select box to 4th column (zero-based index) 
                    // each option has an associated function that returns a boolean 
                    // function variables: 
                    // e = exact text from cell 
                    // n = normalized value returned by the column parser 
                    // f = search filter input value 
                    // i = column index 
                    filter_functions: null,
                    scroller_height : 450, scroller_barWidth : 17, scroller_jumpToHeader:false, scroller_idPrefix : 's_'
                },
                sortList:[[1,0]]
        });
    });