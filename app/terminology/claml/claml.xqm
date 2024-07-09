xquery version "3.0";
(:~
 :   
 :   
 :  @author  : Alexander Henket, Peter Herkenrath
 :  @version : 0.9.0
 :  @date 2018-08-22 
 :)
module namespace claml = "http://enahar.org/exist/apps/terminology/claml";

declare variable $claml:base := '/db/apps/terminologyData';
declare variable $claml:icd10-2012 := '1.2.276.0.76.5.409';
declare variable $claml:hpo        := '2.16.840.1.113883.6.339';
declare variable $claml:orphanet   := '2.16.840.1.113883.2.4.3.46.10.4.1';
declare variable $claml:icf-nl     := '2.16.840.1.113883.6.254';

declare %private function claml:classificationIndexMeta(
          $classificationId as xs:string
        ) as element(classification)?
{
    let $classificationIndex := doc('db/apps/terminology/claml/classification-index.xml')/classificationIndex
    return
        $classificationIndex//classification[@id=$classificationId]
};

declare function claml:class(
              $statusCodes as xs:string*
            , $classificationId as xs:string
            , $code as xs:string?
            , $language as xs:string
            ) as element(Class)?
{
    let $classification := claml:classificationIndexMeta($classificationId)
    let $lll := util:log-app('TRACE','apps.nabu',$classification)

    let $classificationPath := 
            if ($classification[@language=$language]) then
                concat($classification[@language=$language][1]/@collection,'/denormalized')
            else
                concat($classification[1]/@collection,'/denormalized')

    let $lll := util:log-app('TRACE','apps.nabu',$classificationPath)
    let $classes := collection($classificationPath)//ClaML-denormalized[Identifier/@uid=$classificationId]
    let $lll := util:log-app('TRACE','apps.nabu',count($classes))
    let $class :=
            if (string-length($code)=0) then
                $classes/Class[@code='rootClass']
            else 
                $classes/Class[@code=$code]
    let $lll := util:log-app('TRACE','apps.nabu',$class)

    let $class :=
            if (empty($statusCodes)) then
                $class
            else 
                $class[not(Meta[@name='statusCode'])] | $class[Meta[@name='statusCode'][@value=$statusCodes]]

    return
        if (empty($class)) 
        then ()
        (:nothing to return:)
        else
            <Class code="{$class/@code[not(.='rootClass')]}" classificationId="{$classificationId}">
            {
              $class/@kind | $class/Meta | $class/SuperClass
            ,
              if (empty($statusCodes)) then
                   $class/SubClass
              else (
                    $class/SubClass[not(Meta[@name='statusCode'])] | $class/SubClass[Meta[@name='statusCode'][@value=$statusCodes]]
                )
            , $class/Rubric
            }
            </Class>
};

declare function claml:subClasses(
          $statusCodes as xs:string*
        , $classificationId as xs:string
        , $code as xs:string?
        , $language as xs:string
        ) as element(Class)*
{
    let $classification := claml:classificationIndexMeta($classificationId)
    let $lll := util:log-app('TRACE','apps.nabu',$classification)
    let $classificationPath := 
            if ($classification[@language=$language])
            then
                concat($classification[@language=$language][1]/@collection,'/denormalized')
            else
                concat($classification[1]/@collection,'/denormalized')

    let $classes := collection($classificationPath)//ClaML-denormalized[Identifier/@uid=$classificationId]
    let $lll := util:log-app('TRACE','apps.nabu',count($classes))
    let $subclasses := 
            if (string-length($code)=0)
            then
                $classes//Class[not(SuperClass)][not(@code='rootClass')]
            else
                $classes//Class[SuperClass/@code=$code]
    let $lll := util:log-app('TRACE','apps.nabu',$subClasses)
    let $subclasses :=
            if (empty($statusCodes))
            then
                $subclasses
            else 
                $subclasses[not(Meta[@name='statusCode'])] | $subclasses[Meta[@name='statusCode'][@value=$statusCodes]]

    for $class in $subclasses
    return
        <Class code="{$class/@code[not(.='rootClass')]}" classificationId="{$classificationId}">
        {
            $class/@kind | $class/Meta | $class/SuperClass
        ,
            if (empty($statusCodes))
            then
                $class/SubClass
            else
                $class/SubClass[not(Meta[@name='statusCode'])] | $class/SubClass[Meta[@name='statusCode'][@value=$statusCodes]]
        ,   $class/Rubric
        }
        </Class>
};

declare function claml:superClasses(
          $code as xs:string
        , $classification as xs:string
    )
{
    let $codes := tokenize($code,'\s')
    let $classifications :=
            <classifications>
            {
                for $child in xmldb:get-child-collections('/db/apps/terminologyData')
                let $title := collection(concat('/db/apps/terminologyData/',$child))//ClaML/Title
                return
                    if ($title)
                    then
                            <classification collection="{$child}">
                                {$title}
                            </classification>
                    else()
            }
            </classifications>
    let $lll := util:log-app('TRACE','apps.nabu',$classifications)
    let $collection := 
            if (string-length($classification)>0)
            then
                concat(
                          'db/apps/terminologyData/'
                        , $classifications/classification[Title/@name=$classification]/@collection
                        , '/hierarchy'
                    )
            else
                concat(
                          'db/apps/terminologyData/'
                        , $classifications/classification[1]/@collection
                        , '/hierarchy'
                    )
    let $lll := util:log-app('TRACE','apps.nabu',$collection)  
    let $parents :=  collection($collection)//Class[SubClass/@code=$codes]

    return
        <parents>
        {
            for $parent in $parents
            where  every $id in $codes satisfies $id=$parent/SubClass/@code
            return
            $parent
        }
        </parents>
};