/* Wait for DOM to load etc */

$(document).ready(function(){
   
    var lastEvents = [];
    var selectedEvent;
    
    //Initialisations
	initialise_calendar();
});

function findById(source, id) {
  for (var i = 0; i < source.length; i++) {
    if (source[i].id === id) {
      return source[i];
    }
  }
  throw "Couldn't find object with id: " + id;
};



var source = new Array(); // initial view
source[0] = 'modules/getSchedule.xql?alias=u-pmh&group=arzt';
source[1] = 'event/getEvents.xql?alias=u-pmh&group=arzt';
source[2] = 'holidays/getHolidays.xql?alias=alle&group=arzt';

function reload_calendar() {
    var newSource = new Array();
    newSource[0] = 'modules/getSchedule.xql?alias=u-pmh&group=arzt';
    newSource[1] = 'event/getEvents.xql?alias=u-pmh&group=arzt';
    newSource[2] = 'holidays/getHolidays.xql?alias=u-pmh&group=arzt';
    
    $('#calendar').fullCalendar('removeEvents') //Hide all events
    $('#calendar').fullCalendar('removeEventSource', source[0])
    $('#calendar').fullCalendar('removeEventSource', source[1])
    $('#calendar').fullCalendar('removeEventSource', source[2])
    $('#calendar').fullCalendar('addEventSource', newSource[0])
    $('#calendar').fullCalendar('addEventSource', newSource[1])
    $('#calendar').fullCalendar('addEventSource', newSource[2])
    source[0] = newSource[0];
    source[1] = newSource[1];
    source[2] = newSource[2];
}

/* Initialises calendar */
function initialise_calendar(){
        $('#mini-cal').fullCalendar({
            lang: 'de',
            height : 500,
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
            },
            selectable: true,
			selectHelper: true,
			select: function(start, end, allDay) {
                var endtime = $.fullCalendar.formatDate(end,'HH:mm');
                var starttime = $.fullCalendar.formatDate(start,'d-MM-yyyy, HH:mm');
                var mywhen = starttime + ' - ' + endtime;
                $('#newAppointmentForm #apptErbringer').val($('#sp-user').val());
                $('#newAppointmentForm #apptRole').val($('#sp-role').val());
                $('#newAppointmentForm #apptStartTime').val($.fullCalendar.formatDate(start, 'u'));
                $('#newAppointmentForm #apptEndTime').val($.fullCalendar.formatDate(end, 'u'));
                $('#newAppointmentForm #apptAllDay').val(allDay);
                $('#newAppointmentForm #when').text(mywhen);
                // check if erbringer selected
                // close collapsible fieldsets
                // set pat info, if selected; open fieldset
                $('#modalNewAppointment').modal('show');
				// $('#calendar').fullCalendar('unselect');
			}
	});
	

	//Initialise external events
	initialise_external_event('.external-event');
}



/* Initialise event clicks */
function calendar_event_clicked(calEvent, jsEvent, view){
        alert('Event: ' + calEvent.title);
        alert('Coordinates: ' + jsEvent.pageX + ',' + jsEvent.pageY);
        alert('View: ' + view.name);



	/* Set generation values
	set_event_generation_values(
                event.backgroundColor,
                event.borderColor,
                event.textColor,
                event.id,
                event.title,
                event.description,
                event.patID,
                event.user,
                event.sched,
                event.editable
                );
    */
}
