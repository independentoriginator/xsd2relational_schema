select t.xsd_schema_id
     , t.file_name
     , t.package_name
     , t.package_description
     , to_clob('create or replace package {{schema}}.') || t.package_name || ' as'
    || LF || LF || '-- ' || t.package_description
    || LF || LF
    || dbms_xmlgen.convert(
               xmlagg(
                       xmlelement(
                               element
                           , t.table_func_spec
                           , LF || LF
                       ).extract('//text()')
               ).getclobval()
           , 1
       )
    || 'end ' || t.package_name || ';'
    as package_spec
     , to_clob('create or replace package body {{schema}}.') || t.package_name || ' as'
    || LF || LF || '-- ' || t.package_description
    || LF || LF
    || dbms_xmlgen.convert(
               xmlagg(
                       xmlelement(
                               element
                           , t.table_func_body
                           , LF || LF
                       ).extract('//text()')
               ).getclobval()
           , 1
       )
    || 'end ' || t.package_name || ';'
    as package_body
from (select t.xsd_schema_id
           , t.file_name
           , t.package_name
           , t.package_description
           , t.table_path
           , to_clob('select')
        || LF || '	*'
        || LF || 'from'
        || LF || '	xmltable('
        || LF || '		'
        || case
               when t.namespaces is not null then
                   'xmlnamespaces('
                       || LF || '			' || t.namespaces
                       || LF || '		)'
                       || LF || '		, '
                 end
        || '''/''' -- root node is used instead table_path since there is no support for relative paths
        || LF || '		passing'
        || LF || '			:xml_content'
        || LF || '		columns'
        || LF || '			'
        || rtrim(
                     dbms_xmlgen.convert(
                             xmlagg(
                                     xmlelement(
                                             element
                                         , '"' || t.absolute_path || '"'
                                                 || SP || t.target_type
                                                 || ' path ''' || t.absolute_path ||
                                           '''' -- relative paths are not supported in Oracle due to context node limitations
                                         , LF || '			, '
                                     ).extract('//text()') order by
    t.position
                             ).getclobval()
                         , 1
                     )
                 , LF || '			, '
           )
        || LF || '	)'
        as table_query
           , to_clob('-----------------------------------------------------------------------------------------------')
        || LF || '-- XML Table ' || t.table_path
        || LF || '-----------------------------------------------------------------------------------------------'
        || LF || '-- Row type'
        || LF || 'type tr_' || t.target_database_obj_name || ' is record('
        || LF || TAB
        || rtrim(
                     dbms_xmlgen.convert(
                             xmlagg(
                                     xmlelement(
                                             element
                                         , '"' || t.absolute_path || '"' || SP || t.target_type
                                                 || ' -- ' || t.type || ', pattern: ' || t.pattern
                                         , LF || TAB || ', '
                                     ).extract('//text()') order by
    t.position
                             ).getclobval()
                         , 1
                     )
                 , LF || TAB || ', '
           )
        || LF || ');'
        || LF
        || LF || '-- Table type'
        || LF || 'type tt_' || t.target_database_obj_name || ' is table of tr_' || t.target_database_obj_name || ';'
        || LF
        || LF || '-- Table function'
        || LF || 'function f_' || t.target_database_obj_name || '(p_xmldata xmltype) return tt_' ||
             t.target_database_obj_name || ' pipelined;'
        as table_func_spec
           , to_clob('-----------------------------------------------------------------------------------------------')
        || LF || '-- XML Table ' || t.table_path
        || LF || '-----------------------------------------------------------------------------------------------'
        || LF || '-- Table function'
        || LF || 'function f_' || t.target_database_obj_name || '(p_xmldata xmltype) return tt_' ||
             t.target_database_obj_name || ' pipelined as'
        || LF || 'begin'
        || LF || TAB || 'for rec in ('
        || LF || TAB || TAB || 'select'
        || LF || TAB || TAB || TAB || '*'
        || LF || TAB || TAB || 'from'
        || LF || TAB || TAB || TAB || 'xmltable('
        || LF || TAB || TAB || TAB || TAB
        || case
               when t.namespaces is not null then
                   'xmlnamespaces('
                       || LF || TAB || TAB || TAB || TAB || TAB || t.namespaces
                       || LF || TAB || TAB || TAB || TAB || ')'
                       || LF || TAB || TAB || TAB || TAB || ', '
                 end
        || '''/''' -- root node is used instead table_path since there is no support for relative paths
        || LF || TAB || TAB || TAB || TAB || 'passing'
        || LF || TAB || TAB || TAB || TAB || TAB || 'p_xmldata'
        || LF || TAB || TAB || TAB || TAB || 'columns'
        || LF || TAB || TAB || TAB || TAB || TAB
        || rtrim(
                     dbms_xmlgen.convert(
                             xmlagg(
                                     xmlelement(
                                             element
                                         , '"' || t.absolute_path || '"'
                                                 || SP || t.target_type
                                                 || SP || 'path ''' || t.absolute_path ||
                                           '''' -- relative paths are not supported in Oracle due to context node limitations
                                                 || ' -- ' || t.type || ', pattern: ' || t.pattern
                                         , LF || TAB || TAB || TAB || TAB || TAB || ', '
                                     ).extract('//text()') order by t.position
                             ).getclobval()
                         , 1
                     )
                 , LF || TAB || TAB || TAB || TAB || TAB || ', '
           )
        || LF || TAB || TAB || TAB || ')'
        || LF || TAB || ')'
        || LF || TAB || 'loop'
        || LF || TAB || TAB || 'pipe row (rec);'
        || LF || TAB || 'end loop;'
        || LF || TAB || 'return;'
        || LF || 'end f_' || t.target_database_obj_name || ';'
        as table_func_body
           , LF
           , TAB
           , SP
      from (select chr(10)                         as LF  -- Line Feed / New Line
                 , chr(9)                          as TAB -- Horizontal Tab
                 , chr(32)                         as SP  -- Standard Blank Space
                 , t.xsd_schema_id
                 , t.file_name
                 , t.namespaces
                 , t.package_name
                 , t.package_description
                 , t.table_path
                 , t.target_database_obj_name
                 , t.master_table
                 , t.master_table || '/' || c.path as absolute_path
                 , './'
              || rpad(
                           '../'
                       , regexp_count(replace(t.table_path, t.master_table, ''), '/([^/]*) ') * length('../')
                       , '../'
                 ) || c.path                       as relative_path
                 , c.type
                 , case c.type
                       when 'xs:string' then
                           case
                               when nvl(c.length, c.max_length) between 1 and 4000 then
                                   'varchar2(' || nvl(c.length, c.max_length) || ')'
                               else 'clob'
                               end
                       when 'xs:decimal' then 'number'
                           || case
                                  when c.total_digits > 0 then '(' || c.total_digits
                                      || case when c.fraction_digits is not null then ',' || c.fraction_digits end ||
                                                               ')'
                                  else '' end
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
              end                                  as target_type
                 , c.pattern
                 , c.position
            from (with ns_source_name as (select xsd_schema_id
                                               , uri
                                               , regexp_replace(uri,
                                                                '(.+)\:cbdc\.(\d+)\.(\d+)\.(\d+)\.(.+)\_(.+)\.(.+)$',
                                                                '\5')   as essential_name
                                               , regexp_replace(uri,
                                                                '(.+)\:cbdc\.(\d+)\.(\d+)\.(\d+)\.(.+)\_(.+)\.(.+)$',
                                                                '\6\7') as version
                                          from {{schema}}.xsd_namespace)
               , ns_camel_case_split as (
            select
                xsd_schema_id
                    , uri
                    , essential_name as source_name
                    , regexp_replace(essential_name, '([a-z])([A-Z])', '\1 \2') as splitted_name
            from
                ns_source_name
                )
                    , word_reduction as (
            select 'Administration' as original, 'Adm' as reduction
            from dual
            union all
            select 'FIAdministration' as original, 'FIAdm' as reduction
            from dual
            union all
            select 'Notification' as original, 'Notif' as reduction
            from dual
            union all
            select 'FINotification' as original, 'FINotif' as reduction
            from dual
            union all
            select 'FKNotification' as original, 'FKNotif' as reduction
            from dual
            union all
            select 'LPNotification' as original, 'LPNotif' as reduction
            from dual
            union all
            select 'Management' as original, 'Mngmnt' as reduction
            from dual
            union all
            select 'FIManagement' as original, 'FIMngmnt' as reduction
            from dual
            union all
            select 'Organisation' as original, 'Org' as reduction
            from dual
            union all
            select 'Request' as original, 'Req' as reduction
            from dual
            union all
            select 'Response' as original, 'Resp' as reduction
            from dual
            union all
            select 'Registration' as original, 'Reg' as reduction
            from dual
            union all
            select 'Wallet' as original, 'Wlt' as reduction
            from dual
            union all
            select 'FIWallet' as original, 'FIWlt' as reduction
            from dual
            union all
            select 'Customer' as original, 'Cust' as reduction
            from dual
            union all
            select 'Recipient' as original, 'Rcpt' as reduction
            from dual
            union all
            select 'DCARecipient' as original, 'DCARcpt' as reduction
            from dual
            union all
            select 'C2CRecipient' as original, 'C2CRcpt' as reduction
            from dual
            union all
            select 'Sender' as original, 'Sndr' as reduction
            from dual
            union all
            select 'DCASender' as original, 'DCASndr' as reduction
            from dual
            union all
            select 'Message' as original, 'Msg' as reduction
            from dual
            union all
            select 'Transfer' as original, 'Trf' as reduction
            from dual
            union all
            select 'DCTransfer' as original, 'DCTrf' as reduction
            from dual
            union all
            select 'Termination' as original, 'Termntn' as reduction
            from dual
            union all
            select 'Possibility' as original, 'Poss' as reduction
            from dual
            union all
            select 'FIPossibility' as original, 'FIPoss' as reduction
            from dual
            union all
            select 'Report' as original, 'Rpt' as reduction
            from dual
            union all
            select 'Operation' as original, 'Oper' as reduction
            from dual
            union all
            select 'Certificate' as original, 'Cert' as reduction
            from dual
            union all
            select 'FICertificate' as original, 'FICert' as reduction
            from dual
            union all
            select 'Restriction' as original, 'Restr' as reduction
            from dual
            union all
            select 'Border' as original, 'Brdr' as reduction
            from dual
            union all
            select 'Business' as original, 'Bus' as reduction
            from dual
            union all
            select 'Block' as original, 'Blck' as reduction
            from dual
            union all
            select 'Bank' as original, 'Bnk' as reduction
            from dual
            union all
            select 'Refund' as original, 'Refnd' as reduction
            from dual
            union all
            select 'To' as original, '2' as reduction
            from dual
            union all
            select 'For' as original, '4' as reduction
            from dual
                )
                    , namespace_name as (
            select
                xsd_schema_id
                    , uri
                    , source_name
                    , description
                    , shortened_name
            from (
                select
                r.xsd_schema_id
                    , r.uri
                    , r.source_name || '_' || s.version as source_name
                    , r.source_name || ' v' || s.version as description
                    , listagg(
                nvl(r.reduction, r.source)
                    , ''
                ) within group (
                order by
                r.ordinal_position
                )
                || '_' || s.version
                as shortened_name
                from (
                select
                s.xsd_schema_id
                    , s.uri
                    , s.source_name
                    , w.word as source
                    , r.reduction
                    , w.ordinal_position
                from
                ns_camel_case_split s
                cross apply (
                select
                regexp_substr(s.splitted_name, '[^ ]+', 1, level) as word
                    , level as ordinal_position
                from
                dual
                connect by
                level <= regexp_count(s.splitted_name, '[^ ]+')
                ) w
                left join word_reduction r
                on r.original = w.word
                ) r
                join ns_source_name s
                on s.xsd_schema_id = r.xsd_schema_id
                and s.essential_name = r.source_name
                group by
                r.xsd_schema_id
                    , r.uri
                    , r.source_name
                    , s.version
                )
                )
                    , xsd_table as (
            select
                s.id as xsd_schema_id
                    , s.file_name
                    , t.table_path
                    , t.master_table
                    , (
                select
                listagg(
                case
                when ns.prefix is null then
                'default ''' || ns.uri || ''''
                else
                '''' || ns.uri || ''' as "' || ns.prefix || '"'
                end
                    , chr(10) || '	, '
                )
                within group (order by ns.prefix)
                from
                {{schema}}.xsd_namespace ns
                where
                ns.xsd_schema_id = s.id
                ) as namespaces
                    , main_ns.description as package_description
                    , main_ns.shortened_name as package_name
            from
                {{schema}}.xsd_schema s
                join {{schema}}.xsd_table t
            on t.xsd_schema_id = s.id
                outer apply (
                select
                ns_name.shortened_name
                , ns_name.description
                from
                namespace_name ns_name
                where
                ns_name.xsd_schema_id = s.id
                and rownum = 1
                ) main_ns
                )
                , table_path_dir as (
            select
                t.xsd_schema_id
                    , t.file_name
                    , t.table_path
                    , t.master_table
                    , t.namespaces
                    , t.package_name
                    , t.package_description
                    , nvl(dir.dir, t.table_path) as dir
                    , nvl(dir.ordinal_position, 0) as ordinal_position
            from
                xsd_table t
                outer apply (
                select
                regexp_substr(t.table_path, '[^/]+', 1, level) as dir
                    , level as ordinal_position
                from
                dual t
                connect by
                level <= regexp_count(t.table_path, '[^/]+')
                ) dir
                )
                    , essential_path as (
            select
                t.xsd_schema_id
                    , t.file_name
                    , t.table_path
                    , t.master_table
                    , t.namespaces
                    , t.package_name
                    , t.package_description
                    , listagg(
                t.dir
                    , '/'
                ) within
            group (
                order by ordinal_position
                ) as table_essential_path
            from
                table_path_dir t
            where
                (t.xsd_schema_id
                , t.dir
                , t.ordinal_position) not in (
                select
                d.xsd_schema_id
                , d.dir
                , d.ordinal_position
                from
                table_path_dir d
                group by
                d.xsd_schema_id
                , d.dir
                , d.ordinal_position
                having
                count (1) = (
                select
                count (1)
                from
                xsd_table t
                where
                t.xsd_schema_id = d.xsd_schema_id
                )
                )
               or regexp_count(t.table_path
                , '/') = 0
            group by
                t.xsd_schema_id
                    , t.file_name
                    , t.table_path
                    , t.master_table
                    , t.namespaces
                    , t.package_name
                    , t.package_description
                )
                    , abbreviated_path as (
            select
                t.xsd_schema_id
                    , t.file_name
                    , t.table_path
                    , t.master_table
                    , t.namespaces
                    , t.package_name
                    , t.package_description
                    , t.table_essential_path
                    , subpath.subpath
                    , regexp_replace(subpath.subpath, '[a-z]', '') as abbreviated_subpath
                    , regexp_replace(subpath.subpath, '([^/])[^/]*', '\1') as firstchars_only_subpath
            from
                essential_path t
                outer apply (
                select
                substr(t.table_essential_path, 1, instr(t.table_essential_path, '/', 1, level) - 1) as subpath
                    , level as ordinal_position
                from
                dual
                connect by
                level <= regexp_count(t.table_essential_path, '/')
                ) subpath
                )
                    , xsd_table_ext as (
            select
                t.xsd_schema_id
                    , t.file_name
                    , t.table_path
                    , t.master_table
                    , t.namespaces
                    , t.package_name
                    , t.package_description
                    , t.table_essential_path
                    , t.shortened_path
                    , replace(shortened_path, '/', '') as target_database_obj_name
            from (
                select
                t.xsd_schema_id
                    , t.file_name
                    , t.table_path
                    , t.master_table
                    , t.namespaces
                    , t.package_name
                    , t.package_description
                    , t.table_essential_path
                    , t.shortened_path
                    , t.shortened_path_length
                    , row_number()
                over(
                partition by
                t.xsd_schema_id
                    , t.table_path
                order by
                t.shortened_path_length desc
                )
                as rn
                from (
                select
                t.xsd_schema_id
                    , t.file_name
                    , t.table_path
                    , t.master_table
                    , t.namespaces
                    , t.package_name
                    , t.package_description
                    , t.table_essential_path
                    , t.shortened_path
                    , length (shortened_path) as shortened_path_length
                from (
                select
                t.xsd_schema_id
                    , t.file_name
                    , t.table_path
                    , t.master_table
                    , t.namespaces
                    , t.package_name
                    , t.package_description
                    , t.table_essential_path
                    , regexp_replace(t.table_essential_path, t.subpath, t.abbreviated_subpath, 1, 1) as shortened_path
                from
                abbreviated_path t
                union all
                select
                t.xsd_schema_id
                    , t.file_name
                    , t.table_path
                    , t.master_table
                    , t.namespaces
                    , t.package_name
                    , t.package_description
                    , t.table_essential_path
                    , regexp_replace(t.table_essential_path, t.subpath, t.firstchars_only_subpath, 1, 1) as shortened_path
                from
                abbreviated_path t
                ) t
                where
                length (replace(shortened_path, '/', '')) <= 27
                ) t
                ) t
            where
                t.rn = 1
                )
            select
                ht.xsd_schema_id
                    , ht.file_name
                    , ht.namespaces
                    , ht.package_name
                    , ht.package_description
                    , ht.table_path
                    , ht.master_table
                    , t.target_database_obj_name
            from (
                select
                t.xsd_schema_id
                    , t.file_name
                    , t.namespaces
                    , t.package_name
                    , t.package_description
                    , connect_by_root(t.table_path) as table_path
                    , t.table_path as master_table
                from
                xsd_table_ext t
                connect by
                t.xsd_schema_id = prior t.xsd_schema_id
                and t.table_path = prior t.master_table
                start with
                (t.xsd_schema_id
                    , t.table_path) in (
                select
                xsd_schema_id
                    , table_path
                from
                xsd_table_ext
                )) ht
                join xsd_table_ext t
            on t.xsd_schema_id = ht.xsd_schema_id and t.table_path = ht.table_path) t
               join {{schema}}.xsd_column c
      on c.xsd_schema_id = t.xsd_schema_id
          and c.table_path = t.master_table) t
group by LF
       , TAB
       , SP
       , t.xsd_schema_id
       , t.file_name
       , t.namespaces
       , t.package_name
       , t.package_description
       , t.table_path
       , t.target_database_obj_name) t
group by LF
        , TAB
        , SP
        , t.xsd_schema_id
        , t.file_name
        , t.package_name
        , t.package_description