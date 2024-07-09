xquery version "3.0";

module namespace query = "http://enahar.org/exist/apps/nabu/query";

declare namespace fhir= "http://hl7.org/fhir";

declare function query:get-parameters(
          $options as xs:string*
        , $delimiter as xs:string
        ) as node()
{
    let $params :=  
          let $query-string := util:unescape-uri($options, "UTF-8")
          let $parsed-query := tokenize($query-string,$delimiter)
          return <params>
          {for $parsed-query-term in $parsed-query 
                let $parse-query-name := substring-before($parsed-query-term,"=")
                let $parse-query-value := substring-after($parsed-query-term,"=")
                return <param name="{$parse-query-name}" value="{$parse-query-value}"/>
                }
          </params>          
    return 
        $params
};
           
declare function query:get-parameter(
          $options as xs:string*
        , $param-name as xs:string
        , $default-value as xs:string
        , $delimiter as xs:string
) as xs:string*
{
    let $params := query:get-parameters($options, $delimiter)
    let $param-nodes := $params/param[@name=$param-name]
    let $param-values := 
       for $param-node in $param-nodes 
       return 
         if ($param-node/@value) 
         then string($param-node/@value) 
         else $default-value 
    return
        $param-values
};

declare function query:get-parameter-names(
          $options as xs:string*
        , $delimiter as xs:string
        ) as xs:string*
{
    let $params := query:get-parameters($options, $delimiter)
    for $param-name in distinct-values($params/param/@name)
        return
            $param-name
};