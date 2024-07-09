xquery version "3.0";
(: ~
 : Allen interval realations
 : 
 : @author Peter Herkenrath
 : @version 0.2
 : 2015-06-29
 : 
 : 
 :)
module namespace allen ="http://enahar.org/lib/allen";


declare function allen:before($a, $b) as xs:boolean
{
    ($a/@start < $b/@start and $a/@end < $b/@end)
};

declare function allen:meets($a, $b) as xs:boolean
{
    ($a/@start < $b/@start and $a/@end = $b/@start)
};

declare function allen:overlaps($a, $b) as xs:boolean
{
    ($a/@start < $b/@start and $a/@end > $b/@start and $a/@end < $b/@end)
};

declare function allen:finishedBy($a, $b) as xs:boolean
{
    ($a/@start < $b/@start and $a/@end = $b/@end)
};

declare function allen:contains($a, $b) as xs:boolean
{
    ($a/@start < $b/@start and $a/@end > $b/@end)
};

declare function allen:starts($a, $b) as xs:boolean
{
    ($a/@start = $b/@start and $a/@end < $b/@end)
};

declare function allen:equals($a, $b) as xs:boolean
{
    ($a/@start = $b/@start and $a/@end = $b/@end)
};

declare function allen:startedBy($a, $b) as xs:boolean
{
    ($a/@start = $b/@start and $a/@end > $b/@end)
};

declare function allen:during($a, $b) as xs:boolean
{
    ($a/@start > $b/@start and $a/@end < $b/@end)
};

declare function allen:finishes($a, $b) as xs:boolean
{
    ($a/@start > $b/@start and $a/@end = $b/@end)
};

declare function allen:overlapedBy($a, $b) as xs:boolean
{
    ($a/@start > $b/@start and $a/@start < $b/@end and $a/@end > $b/@end)
};

declare function allen:metBy($a, $b) as xs:boolean
{
    ($a/@start = $b/@end and $a/@end > $b/@end)
};

declare function allen:precededBy($a, $b) as xs:boolean
{
    ($a/@start > $b/@end and $a/@end > $b/@end)
};

(:~
 : Allen's Interval Relations
 : p before
 : m meets
 : o overlaps
 : F finishedBy
 : D contains
 : s starts
 : e equals
 : S startedBy
 : d during
 : f finishes
 : O overlapedBy
 : M metBy
 : P precededBy
 :) 
declare function allen:relation($a, $b) as xs:string
{
    if ($a/@start < $b/@start)
    then
        if      ($a/@end < $b/@start) then "p"
        else if ($a/@end = $b/@start) then "m"
        else if ($a/@end > $b/@start and $a/@end < $b/@end) then "o"
        else if ($a/@end = $b/@end )  then "F"
        else                               "D"
    else if ($a/@start = $b/@start)
    then
        if      ($a/@end < $b/@end)   then "s"
        else if ($a/@end = $b/@end)   then "e"
        else                               "S"
    else if ($a/@start > $b/@start and $a/@start < $b/@end)
    then
        if      ($a/@end < $b/@end)   then "d"
        else if ($a/@end = $b/@end)   then "f"
        else                               "O"
    else if ($a/@start = $b/@end)     then "M"
    else                                   "P"
};
