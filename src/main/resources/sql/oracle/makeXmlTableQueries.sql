select
    target_column.xsd_schema_id
     , target_column.file_name
     , target_column.table_path
     , to_clob('select')
    || chr(10) || '	*'
    || chr(10) || 'from'
    || chr(10) || '	xmltable('
    || chr(10) || '		xmlnamespaces(default ''$1'')'
    || chr(10) || '		, ''$2'''
    || chr(10) || '		passing'
    || chr(10) || '			:xml_content'
    || chr(10) || '		columns'
    || chr(10) || chr(9) || chr(9) || chr(9)
    || rtrim(
               dbms_xmlgen.convert(
                       xmlagg(
                               xmlelement(
                                       e
                                   , '"' || target_column.absolute_path || '"'
                                           || ' ' || target_column.target_type
                                           || ' path ''' || target_column.relative_path || ''''
                                   , chr(10) || chr(9) || chr(9) || chr(9) || ', '
                               ).extract('//text()')
                                   order by
		    		target_column.position
                       ).getclobval()
                   , 1
               )
           , chr(10) || chr(9) || chr(9) || chr(9) || ', '
       )
    || chr(10) || chr(9) || ')'
    as table_query
from (
         select
             t.xsd_schema_id
              , t.file_name
              , t.table_path
              , t.master_table
              , t.master_table || '/' || c.path as absolute_path
              , './'
             || rpad(
                        '../'
                    , regexp_count(replace(t.table_path, t.master_table, ''), '/([^/]*)') * length('../')
                    , '../'
                ) || c.path as relative_path
              , c.type
              , case c.type
                    when 'xs:string' then
                        case when nvl(c.length, c.max_length) between 1 and 4000 then 'varchar2(' || nvl(c.length, c.max_length) || ')' else 'clob' end
                    when 'xs:decimal' then 'number'
                        || case when c.total_digits > 0 then '(' || c.total_digits
                            || case when c.fraction_digits is not null then ',' || c.fraction_digits end || ')' else '' end
                    when 'xs:int' then 'number(10)' -- 32-bit integer
                    when 'xs:integer' then 'number(10)' -- 32-bit integer
                    when 'xs:long' then 'number(19)' -- 64-bit integer
                    when 'xs:short' then 'number(5)' -- -128 to 127
                    when 'xs:byte' then 'number(3)' -- -32,768 to 32,767
                    when 'xs:float' then 'binary_float'
                    when 'xs:double' then 'binary_double'
                    when 'xs:boolean' then 'number(1)'
                    when 'xs:date' then 'date'
                    when 'xs:dateTime' then 'timestamp with time zone'
                    when 'xs:time' then 'timestamp with time zone'
                    when 'xs:base64Binary' then 'clob'
                    when 'xs:hexBinary' then 'clob'
                    else 'clob'
             end as target_type
              , c.pattern
              , c.position
         from (
                  with
                      xsd_table as (
                          select
                              s.id as xsd_schema_id
                               , s.file_name
                               , t.table_path
                               , t.master_table
                          from
                              xsd_relational_schema.xsd_schema s
                                  join xsd_relational_schema.xsd_table t
                                       on t.xsd_schema_id = s.id
                          where
                              s.id = 58
                      )
                  select
                      t.xsd_schema_id
                       , t.file_name
                       , connect_by_root(t.table_path) as table_path
                       , t.table_path as master_table
                  from
                      xsd_table t
                      connect by
			t.xsd_schema_id = prior t.xsd_schema_id
			and t.table_path = prior t.master_table
                  start with
                           (t.xsd_schema_id, t.table_path) in (
                      select
                      xsd_schema_id, table_path
                      from
                      xsd_table
                      )
              ) t
                  join xsd_relational_schema.xsd_column c
                       on c.xsd_schema_id = t.xsd_schema_id
                           and c.table_path = t.master_table
     ) target_column
group by
    target_column.xsd_schema_id
       , target_column.file_name
       , target_column.table_path