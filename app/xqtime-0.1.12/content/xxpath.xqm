xquery version "3.0";

(:~
 : Defines XPath 3.0 Goodies.
 : @author Peter Herkenrath
 : @version 1.0
 : @see http://enahar.org
 :
 : from XPath 3.0 spec C.6.1-2
 :)

module namespace xxpath = "http://enahar.org/lib/xxpath";

(: 
-- Given a list of intervals, select those which overlap with at least one other inteval in the set.
import Data.List

type Interval = (Integer, Integer)

overlap (a1,b1)(a2,b2) | b1 < a2 = False
                       | b2 < a1 = False
                       | otherwise = True

mergeIntervals (a1,b1)(a2,b2) = (min a1 a2, max b1 b2)

sortIntervals::[Interval]->[Interval]
sortIntervals = sortBy (\(a1,b1)(a2,b2)->(compare a1 a2))

sortedDifference::[Interval]->[Interval]->[Interval]
sortedDifference [] _ = []
sortedDifference x [] = x
sortedDifference (x:xs)(y:ys) | x == y = sortedDifference xs ys
                              | x < y  = x:(sortedDifference xs (y:ys))
                              | y < x  = sortedDifference (x:xs) ys

groupIntervals::[Interval]->[Interval]
groupIntervals = foldr couldCombine []
  where couldCombine next [] = [next]
        couldCombine next (x:xs) | overlap next x = (mergeIntervals x next):xs
                                 | otherwise = next:x:xs

findOverlapped::[Interval]->[Interval]
findOverlapped intervals = sortedDifference sorted (groupIntervals sorted)
  where sorted = sortIntervals intervals

sample = [(1,3),(12,14),(2,4),(13,15),(5,10)]
:)

declare function xxpath:mergeRuns(
                    $f as function(item()) as xs:anyAtomicType, 
                    $seq as item()*)
                  as item()*
{
    fn:fold-left(fn:tail($seq), fn:head($seq), 
       function($sameSoFar as item()*, $this as item()*) as item()* {
         let $thisValue := $f($this)
         let $sameValue := $f($sameSoFar)
         return
           if ($thisValue = $sameValue)
             then $sameSoFar
           else ($sameSoFar, $this)
       })
};

declare function xxpath:highest(
                     $f as function(item()) as xs:anyAtomicType, 
                     $seq as item()*)
                  as item()*
{
     fn:fold-left(fn:tail($seq), fn:head($seq), 
       function($highestSoFar as item()*, $this as item()*) as item()* {
         let $thisValue := $f($this)
         let $highestValue := $f($highestSoFar[1])
         return
           if ($thisValue gt $highestValue)
             then $this
           else if ($thisValue eq $highestValue)
             then ($highestSoFar, $this)
           else $highestSoFar
       })
};

declare function xxpath:lowest(
                     $f as function(item()) as xs:anyAtomicType, 
                     $seq as item()*)
                  as item()*
{
     fn:fold-left(fn:tail($seq), fn:head($seq), 
       function($lowestSoFar as item()*, $this as item()*) as item()* {
         let $thisValue := $f($this)
         let $lowestValue := $f($lowestSoFar[1])
         return
           if ($thisValue lt $lowestValue)
             then $this
           else if ($thisValue eq $lowestValue)
             then ($lowestSoFar, $this)
           else $lowestSoFar
       })
};

(: 
To find the employees with the highest salary, the function might be called as:

    xxpath:highest(function($emp){$emp/salary}, //employee)
:)

declare function xxpath:sort(
                     $f as function(item()) as xs:anyAtomicType, 
                     $seq as item()*)
                  as item()*
{
     for $item in $seq order by $f($item) return $item
};
