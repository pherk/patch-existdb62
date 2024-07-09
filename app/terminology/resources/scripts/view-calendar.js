/* Wait for DOM to load etc */

$(document).ready(function(){
   
    var lastPatients = [];
    var selectedPatient;
    var lastEvents = [];
    var selectedEvent;
    
    //Initialisations
	initialise_calendar();
//	initialise_color_pickers();
    initialise_search_panel();
	// initialise_buttons();
	initialise_event_generation();
	initialise_update_event();
    $('fieldset.collapsible > legend').append(' (<span style="font-family: monospace;">+</span>)');
    $('fieldset.collapsible > legend').click(function () {
        var $divs = $(this).siblings();
        $divs.toggle();

        $(this).find('span').text(function () {
            return ($divs.is(':visible')) ? '-' : '+';
        });
    });
    $("#sp-patient").select2({
                width: "150px",
                placeholder: "Patient",
                minimumInputLength: 2,
                allowClear: true,
                ajax: { 
                            url: "/exist/restxq/metis/patients",
                            dataType: 'json',
                            data: function (term, page) {
                                return {
                                    page_limit: 10,
                                    query: term // search term
                                };
                            },
                            results: function (data, page) { // parse the results into the format expected by Select2.
                            // since we are using custom formatting functions we do not need to alter remote JSON data
                                lastPatients = data;
                                return {results: data};
                            }
                    },
                dropdownCssClass: "bigdrop", // apply css that makes the dropdown taller
                escapeMarkup: function (m) { return m; }
        });
    $('#sp-patient').on('select2-selecting', function(e){
            var id = e.val;
            console.log('selecting patient id: ' + id);
            selectedPatient = findById(lastPatients,id);
            $('#sp-group').select2('val', selectedPatient.cm.group);
            $('#sp-role').select2('val',  selectedPatient.cm.role);
            $('#sp-user').select2('data',  {id:selectedPatient.cm.alias, text:selectedPatient.cm.name});
            console.log('ff loaded');
        });
    $('#sp-user').on('select2-selecting', function(e){
            var id = e.val;
            console.log(id);
        });
    $("#sp-group").select2({
            width: "150px",
            dropdownCssClass: "bigdrop" // apply css that makes the dropdown taller
        });
    $("#sp-role").select2({
            width: "150px",
            allowClear: true,
            placeholder: 'Ambulanz/S3',
            dropdownCssClass: "bigdrop" // apply css that makes the dropdown taller
        });
    $("#sp-urgent").select2({
            width: "80px",
            dropdownCssClass: "bigdrop" // apply css that makes the dropdown taller
        });
    $("#sp-duration").select2({
            width: "80px",
            dropdownCssClass: "bigdrop" // apply css that makes the dropdown taller
        });
    $("#sp-user").select2({
            width: "150px",
            placeholder: "Erbringer",
            minimumInputLength: 0,
            allowClear: true,
            ajax: { 
                    url: "/exist/restxq/icals/globals/users",
                    dataType: 'json',
                    data: function (term, page) {
                                return {
                                    page_limit: 10,
                                    query: term, // search term
                                    group: $('#sp-group').val(),
                                    sched: $('#sp-role').val()
                                };
                            },
                    results: function (data, page) { // parse the results into the format expected by Select2.
                            // since we are using custom formatting functions we do not need to alter remote JSON data
                                return {results: data};
                            }
                        },
            dropdownCssClass: "bigdrop", // apply css that makes the dropdown taller
            escapeMarkup: function (m) { return m; },
            initSelection : function (element, callback) {
                    var data = {};
                    callback(data);
                }
        });
    $('#sp-group').on('change', function(e){ 
            $('#sp-role').select2('val',1);
            $('#sp-user').select2('data', null)
        });
//    $('#sp-role').change(function(){ $("#sp-user").select2('data',null);
//        });
/*
    $('#miniCalendar').datepicker({
        dateFormat: 'DD, d MM, yy',
        onSelect: function(dateText,dp){
            $('#calendar').fullCalendar('gotoDate',new Date(Date.parse(dateText)));
            $('#calendar').fullCalendar('changeView','agendaDay');
           }
    });

    $('#datetime').appendDtpicker({
        inline :true,
        locale : 'de'
        // hourMin: 8,
        // hourMax: 16,
    });
    $("#evt-duration").select2({
            width: "80px",
            dropdownCssClass: "bigdrop" // apply css that makes the dropdown taller
        });
    $('#datetime').on('change',function(){
            var datetime = $('#datetime').val();
            var date = datetime.split(' ')[0].split('.') // convert german date format
            var newDate = new Date(Date.parse(date[2]+ '-' + date[1] + '-' + date[0]));
            $('#calendar').fullCalendar('gotoDate',newDate);
            $('#calendar').fullCalendar('changeView','agendaDay');
            $("#evt-start").val(datetime);
        });
*/
    $("#sp-freelist").select2({
            width: "150px",
            placeholder: "mögliche Termine",
            minimumInputLength: 0,
            allowClear: true,
            ajax: { 
                url: "/exist/restxq/icals/" + ($('#sp-user').val() || '*') + "/free-events",
                dataType: 'json',
                data: function (term, page) {
                    return {
                        page_limit: 10,
                        query: term, // search term
                        resource : $('#sp-role').val(),
                        duration: $('#sp-duration').val()
                    };
                },
                results: function (data, page) { // parse the results into the format expected by Select2.
                    // since we are using custom formatting functions we do not need to alter remote JSON data
                    lastEvents = data;
                    return {results: data};
                }
            },
            dropdownCssClass: "bigdrop", // apply css that makes the dropdown taller
            escapeMarkup: function (m) { return m; }
        });
    $('#sp-freelist').on('select2-selecting', function(e) {
            var id = e.val;
            selectedEvent = findById(lastEvents,id);
            console.log('goto date: ' + id);
            var date = new Date(id);
            $('#calendar').fullCalendar('changeView', 'agendaDay');
            $('#calendar').fullCalendar('gotoDate',date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDay()+1);
        });
    $('#sp-btn-submit-event').on('click', function(e) {
            $('#pinfo-name').text(selectedPatient.text);
            $('#tinfo-start').text(selectedEvent.start);
            $('#tinfo-end').text(selectedEvent.end);
            $('#tinfo-duration').text(selectedEvent.duration);
            $('#tinfo-role').text(selectedEvent.cm.role);
            $('#tinfo-name').text(selectedEvent.cm.name);
            $('#tinfo-location').text(selectedEvent.location);
            $('#modalAppointmentPatient').modal({'backdrop': 'static'});
        });
    $('#submitPatientEvent').on('click', function(e) {
            e.preventDefault();
            doSubmitPatientEvent();
        });
    $('#submitNewEvent').on('click', function(e) {
            e.preventDefault();
            doSubmitClickEvent();
        });
});

function findById(source, id) {
  for (var i = 0; i < source.length; i++) {
    if (source[i].id === id) {
      return source[i];
    }
  }
  throw "Couldn't find object with id: " + id;
};

function doSubmitClickEvent(){
    console.log('doSubmitClickEvent');
    $.ajax({
        type: "PUT",
        url: '/exist/restxq/icals/' + ($('#sp-user').val() || '*') + '/events',
        data: $('#newAppointmentInfo').serialize(),
        success: function(msg){
            // alert(msg) //hide button and show thank you
            $("#modalAppointmentPatient").modal('hide');
            $("#calendar").fullCalendar('renderEvent',
                {
                    title: $('#sinfo').val(),
                    start: new Date($('#apptStartTime').val()),
                    end: new Date($('#apptEndTime').val()),
                    allDay: ($('#apptAllDay').val() == "true"),
                    editable:   true,
                    description: $('#tinfo-note').val()
                },
                false);
        },
        error: function(){
            alert("failure");
            $("#modalAppointmentPatient").modal('hide');
        }
    });
}

function doSubmitPatientEvent(){
    console.log('doSubmitPatientEvent');
    $.ajax({
        type: "PUT",
        url: '/exist/restxq/icals/' + ($('#sp-user').val() || '*') + '/events',
        // data: $('#newAppointmentInfo').serialize(),
        processData: 'false',
        dataType: 'json',
        contentType: 'application/json',
        data: JSON.stringify({
                        // event params
                        etag:     'patient',
                        start:    $('#tinfo-start').text(),
                        end:      $('#tinfo-end').text(),
                        location: $('#tinfo-location').text(),
                        allDay:   false,
                        //
                        summary:  $('#pinfo-name').text(),
                        description: $('#tinfo-note').val(),
                        // patient params
                        patid:    $('#sp-patient').val(),
                        name:     $('#tinfo-name').text(),
                        group:    $('#sp-group').val(),
                        schedule: $('#sp-role').val(),
                        duration: $('#sp-duration').val(),
                        print:    $('#tinfo-print').is(':checked'),
                        info:     $('#tinfo-info').val()
              }),
        success: function(msg){
            alert('hit') //hide button and show thank you
            $("#modalAppointmentPatient").modal('hide');
            $("#calendar").fullCalendar('renderEvent',
                {
                    title:      $('#pinfo-name').val(),
                    start:      new Date($('#tinfo-start').text()),
                    end:        new Date($('#tinfo-end').text()),
                    allDay:     false,
                    editable:   true,
                    description: $('#tinfo-note').val()
                },
                false); // sticky
        },
        error: function(){
            alert("failure");
            $("#modalAppointmentPatient").modal('hide');
        }
    });
}

/* Initialise buttons */
function initialise_buttons(){

	$('.btn').button();
}

/* Binds and initialises refresh functionality */
function initialise_search_panel(){

    //Bind event
	$('#sp-btn-refresh').bind('click', function(){
        reload_calendar();
    });
}

/* Binds and initialises event generation functionality */
function initialise_event_generation(){
    //Bind event
	$('#btn_new_event').bind('click', function(){

		//Retrieve template event
		var background_color = $('#evt_background_color').val() || '#ffffff';
		var border_color     = $('#evt_border_color').val() || '#000000';
		var text_color       = $('#evt_text_color').val() || '#000000';
		var title       = $('#evt_title').val() || '';
		var description = $('#evt_description').val() || '';
        var patID       = $('#evt_patID').val();
		var user        = $('#evt_user').val();
        var sched       = $('#evt_schedule').val();
        patID = (patID===undefined) ? '' : patID;
	});

//Bind event
	$('#btn_gen_template').bind('click', function(){

		//Retrieve template event
		var template_event   = $('#external_event_template').clone();
		var background_color = $('#evt_background_color').val() || '#ffffff';
		var border_color     = $('#evt_border_color').val() || '#000000';
		var text_color       = $('#evt_text_color').val() || '#000000';
		var title       = $('#evt_title').val() || '';
		var description = $('#evt_description').val() || '';
        var patID       = $('#evt_patID').val();
		var user        = $('#evt_user').val();
        var sched       = $('#evt_schedule').val();
        patID = (patID===undefined) ? '' : patID;

		//Edit id
		$(template_event).attr('id', get_uni_id());

		//Add template data attributes
		$(template_event).attr('data-background', background_color);
		$(template_event).attr('data-border', border_color);
		$(template_event).attr('data-text', text_color);
		$(template_event).attr('data-title', title);
		$(template_event).attr('data-description', description);
        $(template_event).attr('data-patID', patID);
		$(template_event).attr('data-user', user);
        $(template_event).attr('data-sched', sched);
        
		//Style external event
		$(template_event).css('background-color', background_color);
		$(template_event).css('border-color', border_color);
		$(template_event).css('color', text_color);

		//Set text of external event
		$(template_event).text(title);

		//Append to external events container
		$('#external_events').append(template_event);

		//Initialise external event
		initialise_external_event('#' + $(template_event).attr('id'));

		//Show
		$(template_event).fadeIn(2000);
	});
}


/* Initialise external events */
function initialise_external_event(selector){

	//Initialise booking types
	$(selector).each(function(){

		//Make draggable
		$(this).draggable({
			revert: true,
			revertDuration: 0,
			zIndex: 999,
			cursorAt: {
				left: 10,
				top: 1
			}
		});

		//Create event object
		var event_object = {
			title: $.trim($(this).text())
		};

		//Store event in dom to be accessed later
		$(this).data('eventObject', event_object);
	});
}


/* Initialise color pickers
function initialise_color_pickers(){

	//Initialise color pickers
	$('.color_picker').minicolors({
            control: $(this).attr('data-control') || 'hue',
            defaultValue: $(this).attr('data-defaultValue') || '',
            inline: $(this).attr('data-inline') === 'true',
            letterCase: $(this).attr('data-letterCase') || 'lowercase',
            opacity: $(this).attr('data-opacity'),
            position: $(this).attr('data-position') || 'bottom right',
            change: function(hex, opacity) {
                        if( !hex ) return;
                        if( opacity ) hex += ', ' + opacity;
                        try {
                        console.log(hex);
                } catch(e) {}
            },
            theme: 'default'
    });
}
*/

var source = new Array(); // initial view
source[0] = {
                url: '/exist/restxq/enahar/schedules/events',
                type: 'GET',
                contentType: 'application/json',
                startParam : 'rangeStart',
                endParam : 'rangeEnd',
                data: {
                      _format: 'application/json'
                    , actor : function() { return $('.order-select[name="actor-hack"]').val() || ''}
//                    , group : function() { return $('.order-select[name="service-hack"]').val() || ''}
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
                data: {
                      _format: 'application/json'
                    , actor : function() { return $('.order-select[name="actor-hack"]').val() || ''}
//                    , group : function() { if ($('.order-select[name="service-hack"]').val() !== '') { return '' } else { return 'arzt'} }
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

/* Initialises calendar */
function initialise_calendar(){
        $('#calendar').fullCalendar({
            lang: 'de',
            height : 300,
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

/* Handle an external event that has been dropped on the calendar */
function external_event_dropped(date, all_day, external_event){

	//Create vars
	var event_object;
	var copied_event_object;
	var duration = 60;

	//Retrive dropped elemetns stored event object
	event_object = $(external_event).data('eventObject');

	//Copy so that multiple events don't reference same object
	copied_event_object = $.extend({}, event_object);
	
	//Assign reported start and end dates
	copied_event_object.start  = date;
	copied_event_object.end    = new Date(date.getTime() + duration * 60000);
	copied_event_object.allDay = all_day;

	//Assign colors etc
	copied_event_object.backgroundColor = $(external_event).data('background');
	copied_event_object.textColor       = $(external_event).data('text');
	copied_event_object.borderColor     = $(external_event).data('border');

	//Assign text, price, etc
	copied_event_object.id = get_uni_id();
	copied_event_object.title       = $(external_event).data('title');
	copied_event_object.description = $(external_event).data('description');
    copied_event_object.patID = $(external_event).data('patID');
	copied_event_object.user  = $(external_event).data('user');
    copied_event_object.sched = $(external_event).data('sched');

	//Render event on calendar
	$('#calendar').fullCalendar('renderEvent', copied_event_object, false);
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


/* Set event generation values */
function set_event_generation_values(bg_color, border_color, text_color, event_id, title, description, patID, user, sched, editable){
    bg_color    = bg_color     || '#ffffff';
    border_color= border_color || '#000000';
    text_color  = text_color   || '#000000';
    tile        = title || '';
    description = description || '';
    patID = (patID===undefined) ? '' : patID;
    editable    = editable || true;
    
	//Set values
    $('#evt_background_color').minicolors('value', bg_color);
	$('#evt_border_color').val(border_color);
	$('#evt_text_color').val(text_color);
	$('#evt_title').val(title);
    $('#evt_description').val(description);
    $('#evt_patID').text(patID);
    $('#evt_user').text(user);
    $('#evt_schedule').text(sched);
    $('#evt_current_event').val(event_id);
    // enable/disable button
    if (editable) 
        $("#btn_update_event").removeAttr("disabled");
    else
        $("#btn_update_event").attr("disabled", "disabled");
}


/* Generate unique id */
function get_uni_id(){

	//Generate unique id
	return new Date().getTime() + Math.floor(Math.random()) * 500;
}


/* Initialise update event button */
function initialise_update_event(){
	var test = $('#calendar').fullCalendar( 'clientEvents');
	//Bind event
	$('#btn_update_event').bind('click', function(){

		//Create vars
		var current_event_id = $('#evt_current_event').val();
		//Check if value found
		if(current_event_id){

			//Retrieve current event
			var current_event = $('#calendar').fullCalendar('clientEvents', current_event_id);

			//Check if found
			if(current_event && current_event.length == 1){
				//Retrieve current event from array
				current_event = current_event[0];

				//Set values
				current_event.backgroundColor = $('#evt_background_color').val();
				current_event.textColor       = $('#evt_text_color').val();
				current_event.borderColor     = $('#evt_border_color').val();
				current_event.title           = $('#evt_title').val();
                current_event.description     = $('#evt_description').val();
				current_event.patID = $('#evt_patID').val();
				current_event.user  = $('#evt_user').val();
                current_event.sched = $('#evt_schedule').val();

				//Update event
				$('#calendar').fullCalendar('updateEvent', current_event);
			}
		}
	});
}