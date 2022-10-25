set schema 'public';

create or replace procedure create_db
(
	database_name text
)
language plpgsql
as $$
begin
	if exists(select from pg_database where datname = database_name) then
		raise notice 'Database %s already exists.', database_name;
	else
		  perform dblink_exec('dbname=' || current_database()   -- current db
						 , 'CREATE DATABASE ' || quote_ident(database_name));
		  perform dblink_exec('\connect ' || quote_ident(database_name));
	end if;
end $$;

create or replace procedure create_schema
(
	f_schema_name text
)
language plpgsql
as $$
begin
	execute format('create schema if not exists %s;', f_schema_name);
	execute format('create extension if not exists postgis with schema %s;', f_schema_name);
end $$;

create or replace procedure create_tables
(
	f_names text[],
	f_schema_name text
)
language plpgsql
as $$
declare
	f_names_length int = array_length(f_names, 1);
begin
	for i in 1..f_names_length
	loop
		execute format('create table if not exists %s.%s(id int, geometry geometry, name varchar);', f_schema_name, f_names[i]);
	end loop;
end $$;

create or replace procedure build_env
(
	f_db_name text default 'default_db', 
	f_schema_name text default 'default_schema', 
	f_tables_names text[] default array['default_table']
)
language plpgsql
as $$
begin
	create extension if not exists dblink;
	call create_db(f_db_name);
	call create_schema(f_schema_name);
	call create_tables(f_tables_names, f_schema_name);
end $$;

call build_env('lab2', 'lab2_solutions', array['buildings', 'roads', 'poi']);

insert into buildings values(1, 'POLYGON((8 1.5, 10.5 1.5, 10.5 4, 8 4, 8 1.5))', 'BuildingA')
	,(2, 'POLYGON((4 5, 6 5, 6 7, 4 7, 4 5))', 'BuildingB')
	,(3, 'POLYGON((3 6, 5 6, 5 8, 3 8, 3 6))', 'BuildingC')
	,(4, 'POLYGON((9 8, 10 8, 10 9, 9 9, 9 8))', 'BuildingD')
	,(5, 'POLYGON((1 1, 2 1, 2 2, 1 2, 1 1))', 'BuildingF');
	
insert into roads values(1, 'LINESTRING(0 4.5, 12 4.5)', 'RoadX')
	,(2, 'LINESTRING(7.5 10.5, 7.5 0)', 'RoadY');
	
insert into poi values(1, 'POINT(1 3.5)', 'G')
	,(2, 'POINT(5.5 1.5)', 'H')
	,(3, 'POINT(9.5 6)', 'I')
	,(4, 'POINT(6.5 6)', 'J')
	,(5, 'POINT(6 9.5)', 'K');
	
select sum(st_length(geometry)) as total_road_length
from roads;

select st_geometrytype(geometry) as geometry_WKT
	,st_area(geometry) as surface_area
	,st_perimeter(geometry) as circuit
from buildings 
where name = 'BuildingA';

select name
	,st_area(geometry) as surface_area
from buildings
where st_geometrytype(geometry) = 'ST_Polygon'
order by name;

select name
	,st_perimeter(geometry) as circuit
from buildings
order by st_area(geometry) desc
limit 2;

with cte as(
	select geometry
	from buildings
	where name = 'BuildingC'
	union(
		select geometry 
		from poi
		where name = 'K')
)
select st_distance(geometry, lead(geometry) over()) as shortest_distance
from cte
limit 1;

with cte as(
	select geometry
	from buildings
	where name = 'BuildingC' or name = 'BuildingB'
)
select st_area(st_difference(geometry, st_buffer(lead(geometry) over(), 0.5))) as "area>0.5"
from cte
limit 1;

with cte_road as(
select geometry
from roads
where name = 'RoadX'
)
select name as building_name
from buildings b
cross join cte_road c
where st_y(st_centroid(b.geometry)) > st_ymax(c.geometry);

select st_area(st_symdifference(geometry, st_geomfromtext('POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))'))) as surface_area
from buildings 
where name = 'BuildingC';