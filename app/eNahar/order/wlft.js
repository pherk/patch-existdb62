 $(document).ready(function(){
    var group = $(".cal-select[name='group']")
    var subject = $(".cal-select[name='subject']")
    var schedule = $(".cal-select[name='schedule']")
    
    $(".cal-select[name='group']").select2({
        width: "220px",
        placeholder: "bitte wählen",
        minimumInputLength: 0,
        allowClear: 'true',
        ajax: { 
            url: "/exist/restxq/metis/roles",
            dataType: 'json',
            data: function (params) {
                return {
                    name: params.term // search term
                };
            },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                // since we are using custom formatting functions we do not need to alter remote JSON data
                return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $(".cal-select[name='subject']").select2({
        width: "220px",
        placeholder: "bitte wählen",
        minimumInputLength: 0,
        allowClear: 'true',
        ajax: { 
            url: "/exist/restxq/metis/PractitionerRole",
            dataType: 'json',
            data: function (params) {
                return {
                    name: params.term, // search term
                    role: function() { return group.select2('data')[0]===undefined ? 'kikl-spz' : group.select2('data')[0].id }
                };
            },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                // since we are using custom formatting functions we do not need to alter remote JSON data
                return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $(".cal-select[name='schedule']").select2({
        width: "220px",
        placeholder: "bitte wählen",
        minimumInputLength: 0,
        allowClear: 'true',
        ajax: { 
            url: "/exist/restxq/enahar/schedules",
            dataType: 'json',
            data: function (params) {
                return {
                    name: params.term, // search term
                    role: function() { return group.select2('data')[0]===undefined ? 'kikl-spz' : group.select2('data')[0].id }
                };
            },
            processResults: function (data, page) { // parse the results into the format expected by Select2.
                // since we are using custom formatting functions we do not need to alter remote JSON data
                return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $(".cal-select[name='group']").change(function() {
        var gid  = group.select2('data')[0]===undefined ? '' : group.select2('data')[0].id;
        var sid  = subject.select2('data')[0]===undefined ? '' : subject.select2('data')[0].id;
        var schid  = schedule.select2('data')[0]===undefined ? '' : schedule.select2('data')[0].id;
        console.log('group changed');
        redraw(gid,sid,schid);
    });
    $(".cal-select[name='subject']").change(function() {
        var gid  = group.select2('data')[0]===undefined ? '' : group.select2('data')[0].id;
        var sid  = subject.select2('data')[0]===undefined ? '' : subject.select2('data')[0].id;
        var schid  = schedule.select2('data')[0]===undefined ? '' : schedule.select2('data')[0].id;
        console.log('subject changed');
        redraw(gid,sid,schid);
    });
    $(".cal-select[name='schedule']").change(function() {
        var gid  = group.select2('data')[0]===undefined ? '' : group.select2('data')[0].id;
        var sid  = subject.select2('data')[0]===undefined ? '' : subject.select2('data')[0].id;
        var schid  = schedule.select2('data')[0]===undefined ? '' : schedule.select2('data')[0].id;
        console.log('schedule changed');
        redraw(gid,sid,schid);
    });
});
    // global data variable
    var wldata = null;
    var ftdata = null;

    // Convert running log JSON data into readable format for heatmap calendar
function redraw(gid,sid,schid) {

      // set get URL
      var start    = new Date(2016,3,1);
      var end      = new Date(2016,5,30);
      var json_url = "/exist/restxq/enahar/heatmap?"
                        + "actor=" +sid 
                        +"&group=" +gid 
                        +"&schedule=" +schid 
                        +"&rangeStart=" + moment().format("YYYY-MM-DDTHH:mm:ss")
                        +"&rangeEnd=" + moment().add(3,"months").format("YYYY-MM-DDTHH:mm:ss");
      // declare object variable
      var ob1 = {};
      var ob2 = {};

      // Get running log file from repository
      d3.json(json_url)
        .header("Content-Type", "application/json")
        .get(function(error, result) {
        
        // for each data entry
        for (var i = 0; i < result.data.length; i++) {

          // get date and data
          var apoche = date_to_epoch(result['data'][i]['date']).toString();
          var wkload = parseFloat(result['data'][i]['wkload']);
          var fs = parseFloat(result['data'][i]['fs']);

          // set data
          ob1[apoche.toString()] = wkload;
          ob2[apoche.toString()] = fs;
        }
        
        var json_string1 = JSON.stringify(ob1);
        wldata = JSON.parse(json_string1);
        
        var json_string2 = JSON.stringify(ob2);
        ftdata = JSON.parse(json_string2);
        
        moment.locale("de");
        
        var wlcal = new CalHeatMap();
        wlcal.init({
          itemSelector: "#wlcal-heatmap",
            itemNameSpace : "wlcal",
          domain: "month",
          subDomain: "x_day",
          data: wldata,
          start: start,
          cellSize: 20,
          cellPadding: 5,
          domainGutter: 20,
          range: 3,
          domainDynamicDimension: false,
        previousSelector: "#minDate-previous",
        nextSelector: "#minDate-next",

            subDomainTextFormat: "%d",
            legend: [1.0, 4.0, 6.0, 8.0],
            legendColors: {
                empty: "#ededed",
                min: "#40ffd8",
                max: "#f20013"
            },
            domainLabelFormat: function (date) {
//            moment.lang("es");
                return moment(date).format("MMMM YY").toUpperCase();
            },
            subDomainTitleFormat: {
                empty : "keine Termine",
                filled : "{count} {name} am {date}"
            },
            subDomainDateFormat: function(date) {
                return moment(date).format("LL");
            },
            itemName: ["WKLoad", "WKLoad"],
            tooltip : true,
            onClick: function (date, count) {
                alert("OM, " + count + " Workload am " + date.toISOString());
            }
        });
        
        var ftcal = new CalHeatMap();
        ftcal.init({
          itemSelector: "#ftcal-heatmap",
          domain: "month",
          subDomain: "x_day",
          itemNameSpace : "ftcal",
          data: ftdata,
          start: start,
          cellSize: 20,
          cellPadding: 5,
          domainGutter: 20,
          range: 3,
          domainDynamicDimension: false,
        previousSelector: "#minDate-previous",
        nextSelector: "#minDate-next",

            subDomainTextFormat: "%d",
            legend: [1.0, 2.0, 3.0, 4.0],
            legendColors: {
                empty: "#ededed",
                max: "#40ffd8",
                min: "#f20013"
            },
            domainLabelFormat: function (date) {
//            moment.lang("es");
                return moment(date).format("MMMM YY").toUpperCase();
            },
            subDomainTitleFormat: {
                empty : "keine Termine",
                filled : "{count} {name} am {date}"
            },
            subDomainDateFormat: function(date) {
                return moment(date).format("LL");
            },
            itemName: ["Score", "Score"],
            tooltip : true,
            onClick: function (date, count) {
                alert("OM, " + count + " Slots am " + date.toISOString());
            }
        });
      });
    }

    // Convert strings to date objects 
    function date_to_epoch(key) {
      var epoch_seconds = Date.parse(key);
      return Math.floor(epoch_seconds / 1000);
    }
