select * 
from t2019_kar_buildings
limit 10;

select tkb19.gid,
	tkb19.polygon_id,
	tkb19.name,
	tkb19.type,
	tkb19.height,
	st_astext(tkb19.geom)
from t2019_kar_buildings tkb19
left join t2018_kar_buildings tkb18
on tkb19.geom = tkb18.geom
where tkb18.gid is null;

with cte_1 as(
	select tkb19.gid,
		tkb19.polygon_id,
		tkb19.name,
		tkb19.type,
		tkb19.height,
		st_astext(tkb19.geom)
	from t2019_kar_buildings tkb19
	left join t2018_kar_buildings tkb18
	on tkb19.geom = tkb18.geom
	where tkb18.gid is null
),
cte_2 as(
	select *
	from t2019_kar_poi_table k19
	left join t2018_kar_poi_table k18
	on k19.geom = k18.geom
	where k18.gid is null
),
--create view result as
cte_result as(
	select x.type
	from cte_2 x 
	join cte_1 y
	on st_intersects(x.geom, st_buffer(y.geom, 0.005))
)
select count(*)
from cte_result
group by type;

select * 
from t2019_kar_streets
limit 10;

create table streets_reprojected(
	gid int primary key,
	link_id float8,
	st_name varchar(254) null,
	ref_in_id float8,
	nref_in_id float8,
	func_class varchar(1),
	speed_cat varchar(1),
	fr_speed_I float8,
	to_speed_I float8,
	dir_travel varchar(1),
	geom geometry
);

insert into streets_reprojected
select gid,
	link_id,
	st_name,
	ref_in_id,
	nref_in_id,
	func_class,
	speed_cat,
	fr_speed_l,
	to_speed_l,
	dir_travel,
	ST_Transform(ST_SetSRID(geom,4326), 3068)
from t2019_kar_streets;

select *
from streets_reprojected
limit 10;

create table input_points(
	id int primary key,
	name varchar(254),
	geom geometry
);

insert into input_points values (1, 'point1', 'POINT(8.36093 49.03174)'),
    (2, 'point2', 'POINT(8.39876 49.00644)');

update input_points
set geom = st_transform(st_setsrid(geom,4326), 3068);

select * 
from t2019_kar_street_node
limit 10;

update t2019_kar_street_node
set geom = st_transform(st_setsrid(geom,4326), 3068);

with cte as(
	select st_makeline(geom) as line
	from input_points
)
select *
from cte x
cross join t2019_kar_street_node y
where st_contains(st_buffer(x.line, 0.002), y.geom);

select * 
from t2019_kar_land_use_a
limit 10;

with cte as(
	select st_buffer(geom,0.003) as buffer 
	from t2019_kar_land_use_a
	where type='Park (City/County)'
)
select count(*) 
from cte 
cross join t2019_kar_poi_table x
where x."type" ='Sporting Goods Store' and st_contains(cte.buffer, x.geom);

select st_intersection(railways.geom, waterlines.geom) as intersect
into T2019_KAR_BRIDGES
from t2019_kar_railways railways
join t2019_kar_water_lines waterlines
on st_intersects(railways.geom, waterlines.geom);

select * 
from t2019_kar_bridges
limit 10;


