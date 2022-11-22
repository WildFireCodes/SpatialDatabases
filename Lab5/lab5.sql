-- create database lab5;

create extension postgis;

create table obiekty(id int, geometry geometry, name varchar);
insert into obiekty(id, geometry, name) values (1, st_collect(array[st_geomfromtext('linestring(0 1, 1 1)'), 
												st_geomfromtext('circularstring(1 1, 2 0, 3 1)'), 
												st_geomfromtext('circularstring(3 1, 4 2, 5 1)'), 
												st_geomfromtext('linestring(5 1, 6 1)')]), 'obiekt1');
select * from obiekty;

insert into obiekty(id, geometry, name) values (2, st_collect(array[st_geomfromtext('linestring(10 6, 14 6)'), 
												st_geomfromtext('circularstring(14 6, 16 4, 14 2)'), 
												st_geomfromtext('circularstring(14 2, 12 0, 10 2)'), 
												st_geomfromtext('linestring(10 2, 10 6)'), 
												st_geomfromtext('circularstring(11 2, 12 2, 11 2)')]), 'obiekt2');
												
select * from obiekty;

insert into obiekty values (3, st_makepolygon( st_geomfromtext('linestring(7 15, 10 17, 12 13, 7 15)')), 'obiekt3'); 
insert into obiekty values (4, st_linefrommultipoint('multipoint(20 20, 25 25, 27 24, 25 22, 26 21, 22 19, 20.5 19.5)'), 'obiekt4'); 
insert into obiekty values (5, 'multipoint(30 30 59,38 32 234)', 'obiekt5'); 
insert into obiekty values (6, st_collect(array[st_geomfromtext('linestring(1 1, 3 2)'), st_geomfromtext('point(4 2)')]), 'obiekt6');

select * from obiekty;

select st_area(st_buffer(st_shortestline((select geometry from obiekty where name = 'obiekt3'), 
										 (select geometry from obiekty where name = 'obiekt4')),5));

--ostatnia wspolrzedna musi pokrywac sie z pierwsza

update obiekty 
set geometry = st_makepolygon(st_addpoint(geometry, 'point(20 20)')) 
where name = 'obiekt4';

insert into obiekty values (7, st_collect((select geometry from obiekty where name = 'obiekt3'), 
										  (select geometry from obiekty where name = 'obiekt4')), 'obiekt7');
										  
select * from obiekty;

select name, 
	st_area(st_buffer(geometry,5))
from obiekty
where st_hasarc(geometry) = false;
