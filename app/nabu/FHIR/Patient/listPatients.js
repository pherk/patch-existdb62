$(document).ready(function() {
    $('#example').DataTable( {
        "processing": true,
        "serverSide": true,
        "deferLoading": 10,
        "ajax": '/exist/restxq/nabu/patientsDT',
        "type": 'get',
        "columns": [
            { data : 'id'},
            { data : 'family'},
            { data : 'given' },
            { data : 'birthDate' }
            ],
        "columnDefs": [
            {
                "targets": [ 0 ],
                "visible": true,
                "searchable": true,
                "render": function ( data, type, full, meta ) {
                    return '<a href="'+data+'">Details</a>';
                }
            }
        ],
        "dataSrc": function ( json ) {
            for ( var i=0, ien=json.data.length ; i<ien ; i++ ) {
                json.data[i][1] = '<a href="/message/'+json.data[i][1]+'>View message</a>';
            }
            return json.data;
        }
    } );
});