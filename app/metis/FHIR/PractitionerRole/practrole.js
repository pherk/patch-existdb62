$(document).ready(function () {      
    $('#accounts tr').click(function (event) {
        if ($(this).attr('id')!='0') {
          window.location.href = "/exist/apps/metis/admin.html?action=show&what=newaccount&uid="+$(this).attr('id'); //redirect to edit form         
        }
        });
    });
    $(function() {
        $("#accounts").tablesorter({theme:'blue',
                                    dateFormat : "yyyymmdd", // set the default date format
                                    widthFixed     : false,
                                    showProcessing : true,
                                    headerTemplate : '{content} {icon}',
                                    widgets:['zebra', 'filter', 'scroller'],
                                    widgetOptions : {
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
                                    sortList:[[0,0]]
        });
    });