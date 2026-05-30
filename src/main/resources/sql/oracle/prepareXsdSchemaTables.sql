begin
    for ddl in (
        select '
            create user {{schema}} identified by "{{schema}}"
            default tablespace users
            quota unlimited on users
            ' as cmd_text
            , 0 as ordinal_num
        from
            dual
        left join sys.all_users u
            on u.username = upper('{{schema}}')
        where
            u.user_id is null
        union all
        select
            'drop table ' || t.owner || '.' || t.table_name as cmd_text
            , xsd_t.ordinal_num
        from
            sys.all_tables t
            join (
                select
                    column_value as table_name
                    , row_number() over(order by rownum desc) as ordinal_num
                from
                    table(
                        sys.odcivarchar2list(
                            'xsd_schema'
                            , 'xsd_namespace'
                            , 'xsd_table'
                            , 'xsd_column'
                        )
                    )
            ) xsd_t
                on upper(xsd_t.table_name) = t.table_name
        where
            t.owner = upper('{{schema}}')
        union all
        select
            column_value as cmd_text
            , 10 + rownum as ordinal_num
        from
            table(
                sys.odcivarchar2list(
                    'create table {{schema}}.xsd_schema (
                        id number(38) generated always as identity primary key
                        , file_name varchar2(255) not null
                        , file_content xmltype
                    )'
                    , 'create table {{schema}}.xsd_namespace (
                        xsd_schema_id number(38) not null references {{schema}}.xsd_schema (id)
                        , uri varchar2(255) not null
                        , prefix varchar2(127) null
                        , primary key (xsd_schema_id, uri)
                    )'
                    , 'create table {{schema}}.xsd_table (
                        xsd_schema_id number(38) not null references {{schema}}.xsd_schema (id)
                        , table_path varchar2(511) not null
                        , master_table varchar2(511) null
                        , primary key (xsd_schema_id, table_path)
                    )'
                    , 'create table {{schema}}.xsd_column (
                        xsd_schema_id number(38) not null
                        , table_path varchar2(511) not null
                        , path varchar2(255) not null
                        , name varchar2(127) not null
                        , position number(10) not null
                        , type varchar2(127) not null
                        , pattern varchar2(255) null
                        , length number(10) null
                        , max_length number(10) null
                        , total_digits number(10) null
                        , fraction_digits number(10) null
                        , is_multivalued number(1) null
                        , primary key (xsd_schema_id, table_path, path)
                        , constraint fk_xsd_column
                            foreign key (xsd_schema_id, table_path)
                            references {{schema}}.xsd_table (xsd_schema_id, table_path)
                            deferrable initially deferred
                    )'
                )
            )
        order by
            ordinal_num
    )
    loop
        execute immediate
            ddl.cmd_text
        ;
    end loop;
end;
