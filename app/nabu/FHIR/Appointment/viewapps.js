/* Wait for DOM to load etc */

$(document).ready(function(){
     $('.app-select[name="actor-hack"]').select2({
        width: "160px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 0,
        ajax: { 
            url: "/exist/restxq/metis/users",
            contentType: 'application/json',
            dataType: 'json',
            delay: 300,
            data: function (params) {
                var role = $('.app-select[name="service-hack"]').val();
                // console.log(role);
                return {
                    name: params.term, // search term
                    role : role || 'kikl-spz',
                    start: 1,
                    length: '*'
                };
            },
        processResults: function (data, page) { // parse the results into the format expected by Select2.
            // since we are using custom formatting functions we do not need to alter remote JSON data
            return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.app-select[name="actor-hack"]').change(function() {
        var data = $('.app-select[name="actor-hack"]').select2('data');
        $('#calendar').fullCalendar( 'refetchEvents' );
    });
    $('.app-select[name="service-hack"]').select2({
        width: "160px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 0,
        ajax: { 
            url: "/exist/restxq/metis/roles?filter=service",
            contentType: 'application/json',
            dataType: 'json',
            delay: 300,
            data: function (params) {
                return {
                    name: params.term, // search term
                    start: 1,
                    length: '*'
                };
            },
        processResults: function (data, page) { // parse the results into the format expected by Select2.
            // since we are using custom formatting functions we do not need to alter remote JSON data
            return {results: data};
            }
        },
        escapeMarkup: function (m) { return m; }
    });
    $('.app-select[name="service-hack"]').change(function() {
        var data = $('.app-select[name="service-hack"]').select2('data');
        $('#calendar').fullCalendar( 'refetchEvents' );
    });   
    
    initialise_calendar();
});

    //Initialisations
    var source = new Array(); // initial view
    source[0] = {
                url: '/exist/restxq/enahar/schedules/events',
                type: 'GET',
                contentType: 'application/json',
                startParam : 'rangeStart',
                endParam : 'rangeEnd',
                data: {
                      _format: 'application/json'
                    , actor : function() { return $('.app-select[name="actor-hack"]').val() || ''}
                    , group : function() { if ($('.app-select[name="actor-hack"]').val() !== '') { return '' } else { return $('.app-select[name="service-hack"]').val()} }
//                    , sched : ''
                },
                error: function() {
                    alert('error while fetching schedules for calendar!');
                },
                backgroundColor: 'yellow',   // a non-ajax option
                textColor: 'black', // a non-ajax option
                rendering: 'background'
            };
    source[1] = {
                url: '/exist/restxq/nabu/appointments',
                type: 'GET',
                contentType: 'application/json',
                startParam : 'rangeStart',
                endParam : 'rangeEnd',
                traditional : true,
                data: {
                      _format: 'application/json'
                    , actor : function() { return $('.app-select[name="actor-hack"]').select2('data')[0].id || ''}
                    , group : function() { if ($('.app-select[name="actor-hack"]').select2('data')[0].id !== '') { return '' } else { return $('.app-select[name="service-hack"]').select2('data')[0].id} }
                    , status : ['booked','fulfilled','tentative','noshow','arrived','registered']
                },
                error: function() {
                    alert('error while fetching appointments for calendar!');
                },
                color: 'blue',   // a non-ajax option
                textColor: 'white' // a non-ajax option
            };
    source[2] =  {
                url: '/exist/restxq/enahar/holidays',
                type: 'GET',
                contentType: 'application/json',
                startParam : 'rangeStart',
                endParam : 'rangeEnd',
                data: {
                    _format: 'application/json',
                },
                error: function() {
                    alert('error while fetching holidays!');
                },
                color: 'yellow',   // a non-ajax option
                textColor: 'black' // a non-ajax option
            };
    source[3] =  {
                url: '/exist/restxq/metis/leaves',
                type: 'GET',
                contentType: 'application/json',
                startParam : 'rangeStart',
                endParam : 'rangeEnd',
                traditional : true,
                data: {
                    _format: 'application/json'
                    , actor : function() { return $('.app-select[name="actor-hack"]').select2('data')[0].id || ''}
                    , group : function() { if ($('.app-select[name="actor-hack"]').select2('data')[0].id !== '') { return '' } else { return $('.app-select[name="service-hack"]').select2('data')[0].id || ''} }
                    , status: ['confirmed','tentative']
                },
                error: function() {
                    alert('error while fetching leaves!');
                },
                color: 'green',   // a non-ajax option
                textColor: 'black' // a non-ajax option
            };            

    /* Initialises calendar */
    function initialise_calendar(){
        $('#calendar').fullCalendar({
            lang: 'de',
            height : 600,
            defaultView : 'agendaWeek',
            slotEventOverlap: false,
            header: {
				left: 'prev,next today',
				center: 'title',
				right: 'month,agendaWeek,agendaDay'
			},
            buttonText : {
                today:    'heute',
                month:    'Monat',
                week:     'Woche',
                day:      'Tag'
            },
			editable: true,
			startEditable: true,
			durationEditable: true,
            titleFormat : {
                week: "D MMM YYYY", 
                day: 'dddd D MMM YY'
            },
            timeFormat : {
                // for agendaWeek and agendaDay
                agenda: 'H(:mm)', // 5:00 - 6:30
                // for all other views
                '': 'HH(:mm)'             // 24:00
            },
            minTime : "08:00:00",
            maxTime : "20:00:00",
            axisFormat : 'H:mm',
            columnFormat : {
                month: 'ddd',  
                week: 'ddd D', 
                day: 'dddd DD-MM-YY'  // Montag 10-03-13
            },
            firstDay : 1,
            weekends: false,
            monthNames : ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli',
                          'August', 'September', 'Oktober', 'November', 'Dezember'],
            monthNamesShort : ['Jan', 'Feb', 'Mar', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'],
            dayNames : ['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag'],
            dayNamesShort : ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'],
            allDayDefault : false,
            allDaySlot: true,
            allDayText: 'ganztags',
            slotMinutes: 30,
            /*
firstHour: 8,
defaultEventMinutes: 60,
dragOpacity: {
    agenda: .5
},
*/
			eventSources: source,
/*
            eventMouseover: function( event, jsEvent, view ) { 
                var item = $(this);
                if(item.find('.nube').length === 0){
                    var info = '<span class="nube"><h3>' + event.title + '</h3></span>';
                    item.append(info);
                }
                if(parseInt(item.css('top')) < 200){
                    item.find('.nube').css({'top': 20,'bottom':'auto'});
                    item.parent().find('.fc-event').addClass('z0');
                }
                item.find('.nube').stop(true,true).fadeIn();
                // item.css('border-color', 'red');
            },
            eventMouseout: function( event, jsEvent, view ) { 
                            var item = $(this);
                            item.find('.nube').stop(true,true).fadeOut();
                            // remove nube span
            },
*/
            eventRender: function(event, element) {
                element.qtip({
                    content: event.title || 'no title'
                });
            },
/*
            eventDrop: function(event, delta) {
				alert(event.title + ' was moved ' + delta + ' days\n' +
					'(should probably update your database)');
			},
            droppable: true,
            drop: function(date, all_day){
                external_event_dropped(date, all_day, this);
            },
            dayClick: function(date, allDay, jsEvent, view) {
                    $('#calendar').fullCalendar('gotoDate',date);
                    $('#calendar').fullCalendar('changeView', 'agendaDay');
            },
*/
            eventClick: function(cal_event, js_event, view){
                // change the border color just for fun
                $(this).css('border-color', 'red');
                // calendar_event_clicked(cal_event, js_event, view);
                return false;
            }
        });
    }


