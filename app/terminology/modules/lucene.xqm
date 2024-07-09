xquery version "3.0";
(:~
 :   
 :   
 :  @author  : Peter Herkenrath
 :  @version : 0.7.0
 :  @date 2016-12-02 
 :)
module namespace lucene = "http://enahar.org/exist/apps/terminology/lucene";

declare variable $lucene:maxResults := xs:integer('50');

(:~
:   Returns lucene config xml for a sequence of strings. The search will find yield results that match all terms+trailing wildcard in the sequence
:   Example output:
:   <query>
:       <bool>
:           <wildcard occur="must">term1*</wildcard>
:           <wildcard occur="must">term2*</wildcard>
:       </bool>
:   </query>
:
:   @param $searchTerms 
:   @return lucene config
:)
declare function lucene:getSimpleLuceneQuery($searchTerms as xs:string+) as element() {
    lucene:getSimpleLuceneQuery($searchTerms, 'wildcard')
};

(:~
:   
:)
declare function lucene:getSimpleLuceneQuery($searchTerms as xs:string+, $searchType as xs:string) as element() {
    <query>
        <bool>
        {
            for $term in $searchTerms
            return
                if ($searchType='fuzzy') then
                    <fuzzy occur="must">{concat($term,'~')}</fuzzy>
                
                else if ($searchType='fuzzy-not') then
                    <fuzzy occur="not">{concat($term,'~')}</fuzzy>
                    
                else if ($searchType='regex') then
                    <regex occur="must">{$term}</regex>
                    
                else if ($searchType='regex-not') then
                    <regex occur="not">{$term}</regex>
                    
                else if ($searchType='phrase') then
                    <phrase occur="must">{$term}</phrase>
                    
                else if ($searchType='phrase-not') then
                    <phrase occur="not">{$term}</phrase>
                    
                else if ($searchType='term') then
                    <term occur="must">{$term}</term>
                    
                else if ($searchType='term-not') then
                    <term occur="not">{$term}</term>
                    
                else if ($searchType='wildcard') then
                    <wildcard occur="must">{concat($term,'*')}</wildcard>
                    
                else if ($searchType='wildcard-not') then
                    <wildcard occur="not">{concat($term,'*')}</wildcard>
                    
                else ()
        }
        </bool>
    </query>
};

(:~
:   Returns lucene options xml that instruct filter-rewrite=yes
:)
declare function lucene:getSimpleLuceneOptions() as element() {
    <options>
        <default-operator>and</default-operator>
        <phrase-slop>0</phrase-slop>
        <leading-wildcard>no</leading-wildcard>
        <filter-rewrite>yes</filter-rewrite>
    </options>
};

