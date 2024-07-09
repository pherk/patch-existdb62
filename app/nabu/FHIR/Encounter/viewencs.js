// Wait for DOM to load etc 
/* Fullcalendar
dayClick: function(date, allDay, jsEvent, view) {
$(datePickerDiv).datepicker("setDate", date);
}

onChangeMonthYear: function(year, month, inst) {
   if ($(calendarDiv).fullCalendar('getView').name === 'month') {
      $(calendarDiv).fullCalendar('gotoDate', year, month - 1);
   } else {
      $(calendarDiv).fullCalendar('prefetchMonth', new Date(year, month - 1, 2));
   }
},
beforeShowDay: function(date) {
 code determining the class for a day, according to whether there are special
events on that day
   ...
}
*/
$(document).ready(function(){
    $('.app-select[name="actor-hack"]').select2({
        width: "160px",
        placeholder: "Filter eingeben",
        allowClear: true,
        minimumInputLength: 0,
        ajax: { 
            url: "/exist/restxq/metis/PractitionerRole",
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
                url: '/exist/restxq/nabu/encounters',
                type: 'GET',
                contentType: 'application/json',
                startParam : 'rangeStart',
                endParam : 'rangeEnd',
                traditional : true,
                data: {
                      _format: 'application/json'
                    , actor : function() { return $('.app-select[name="actor-hack"]').select2('data')[0].id || ''}
                    , group : function() { if ($('.app-select[name="actor-hack"]').select2('data')[0].id !== '') { return '' } else { return $('.app-select[name="service-hack"]').select2('data')[0].id} }
                    , status : ['planned','finished','tentative','triaged','arrived','in-progress','cancelled']
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
				left: 'prev,next today datePickerButton',
				center: 'title',
				right: 'month,agendaWeek,agendaDay'
			},
        customButtons: {
            datePickerButton: {
                text : 'Cal',
                themeIcon:'circle-triangle-s',
                click: function () {


                    var $btnCustom = $('.fc-datePickerButton-button'); // name of custom  button in the generated code
                    $btnCustom.after('<input type="hidden" id="hiddenDate" class="datepicker" />');

                    $("#hiddenDate").datepicker({
                        autoclose : true,
                        calendarWeeks : true,
                        language : 'de',
                        format : "yyyy-mm-dd"
                    });
                    $("#hiddenDate").on('changeDate', function() {
                            var dateText= $('#hiddenDate').datepicker('getFormattedDate');
                            $('#calendar').fullCalendar('gotoDate', dateText);
                    });

                    var $btnDatepicker = $(".ui-datepicker-trigger"); // name of the generated datepicker UI 
                    //Below are required for manipulating dynamically created datepicker on custom button click
                    $("#hiddenDate").show().focus().hide();
                    $btnDatepicker.trigger("click"); //dynamically generated button for datepicker when clicked on input textbox
                    $btnDatepicker.hide();
                    $btnDatepicker.remove();
                    $("input.datepicker").not(":first").remove();//dynamically appended every time on custom button click

                }
            }
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
            weekNumbers : true,
            weekNumberCalculation: 'ISO',
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
    var tooltip = $('<div/>').qtip({
        id: 'fullcalendar',
        prerender: true,
        content: {
            text: ' ',
            title: {
                button: true
            }
        },
        position: {
            my: 'bottom center',
            at: 'top center',
            target: 'mouse',
            viewport: $('#fullcalendar'),
            adjust: {
                mouse: false,
                scroll: false
            }
        },
        show: false,
        hide: false,
        style: 'qtip-light'
    }).qtip('api');
        eventMouseover : function(data, event, view) {
            var content = '<h3>'+data.title+'</h3>' + 
                '<p><b>Start:</b> '+data.start+'<br />' + 
                (data.end && '<p><b>End:</b> '+data.end+'</p>' || '');

            tooltip.set({
                'content.text': content
            })
            .reposition(event).show(event);
        },
*/
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
                    content: {
                        'title' : event.title,
                        'text' : event.description + ': ' + (event.history || '') + ': ' + (event.partof || '')
                    }
                });
                if (event.partof) {
                    element.find('.fc-content').prepend('<span class="yellowdot"></span> '); 
                }
                if (event.app == 'FIRST') {
                    element.find('.fc-content').prepend('<span class="greendot"></span> '); 
                }
                if (event.app == 'NOCM' || event.app == 'ROUTINE') {
                    element.find('.fc-content').prepend('<span class="reddot"></span> '); 
                }
                if (event.rendering == 'background') {
                    element.append(event.title);
                }
                /*
                      if (event.color) {
                                 element.css('background-color', event.color)
                       }
                */
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
                console.log(cal_event)
                window.open('index.html?action=listPatients&id='+cal_event.pid,'_blank');
                return false;
            }
        });
    }


