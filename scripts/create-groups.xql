xquery version "3.1";
declare option exist:serialize "method=text media-type=text/plain";

try {(
	if (not(sm:group-exists("com"))) then (
		sm:create-group("com"), 
		sm:add-group-member("com", "admin")
	) else (),
	if (not(sm:group-exists("prj"))) then (
		sm:create-group("prj"),
		sm:add-group-member("prj", "admin")
	) else (),
	if (not(sm:group-exists("deleted"))) then sm:create-group("deleted") else ()
)} catch * {
	$err:description
}