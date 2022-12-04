--Nowa baza
create database lab6;
--Struktura
alter schema schema_name rename to adamiak;
--Ladowanie danych
/usr/bin/pg_restore --host "localhost" --port "5432" --username "postgres" --no-password --dbname "lab6" --section=pre-data --verbose "/home/wildfire/Downloads/postgis_raster_backup
raster2pgsql -s 32767 -t 100x100 -I -C -M -d srtm_1arc_v3.tif rasters.dem | psql -d lab6 -h localhost -U postgres -p 5432 
raster2pgsql -s 32767 -t 100x100 -I -C -M -d Landsat8_L1TP_RGBN.tif rasters.landsat8 | psql -d lab6 -h localhost -U postgres -p 5432 
--Tworzenie rastrów z istniejących rastrów i interakcja z wektorami
--Przyklad 1
alter table adamiak.intersects
add column rid SERIAL PRIMARY KEY;

CREATE INDEX idx_intersects_rast_gist ON adamiak.intersects
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('adamiak'::name,
'intersects'::name,'rast'::name);

CREATE TABLE adamiak.intersects AS
SELECT a.rast, b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';

--Przyklad 2
CREATE TABLE adamiak.clip AS
SELECT ST_Clip(a.rast, b.geom, true), b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality like 'PORTO';

--Przyklad 3
CREATE TABLE adamiak.union AS
SELECT ST_Union(ST_Clip(a.rast, b.geom, true))
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast);

--Tworzenie rastrów z wektorów (rastrowanie)
--Przyklad 1
CREATE TABLE adamiak.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1
)
SELECT ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

--Przyklad 2
DROP TABLE adamiak.porto_parishes; --> drop table porto_parishes first
CREATE TABLE adamiak.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1
)
SELECT st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

--Przyklad 3
DROP TABLE adamiak.porto_parishes; --> drop table porto_parishes first
CREATE TABLE adamiak.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1 )
SELECT st_tile(st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-
32767)),128,128,true,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

--Konwertowanie rastrow na wektory (wektoryzowanie)
--Przyklad 1
create table adamiak.intersection as
SELECT
a.rid,(ST_Intersection(b.geom,a.rast)).geom,(ST_Intersection(b.geom,a.rast)
).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

--Przyklad 2
CREATE TABLE adamiak.dumppolygons AS
SELECT
a.rid,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).geom,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

--Analiza rastrow
--Przyklad 1
CREATE TABLE adamiak.landsat_nir AS
SELECT rid, ST_Band(rast,4) AS rast
FROM rasters.landsat8;

--Przyklad 2
CREATE TABLE adamiak.paranhos_dem AS
SELECT a.rid,ST_Clip(a.rast, b.geom,true) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

--Przyklad 3
CREATE TABLE adamiak.paranhos_slope AS
SELECT a.rid,ST_Slope(a.rast,1,'32BF','PERCENTAGE') as rast
FROM adamiak.paranhos_dem AS a;

--Przyklad 4
CREATE TABLE adamiak.paranhos_slope_reclass AS
SELECT a.rid,ST_Reclass(a.rast,1,']0-15]:1, (15-30]:2, (30-9999:3',
'32BF',0)
FROM adamiak.paranhos_slope AS a;

--Przyklad 5
SELECT st_summarystats(a.rast) AS stats
FROM adamiak.paranhos_dem AS a;

--Przyklad 6
SELECT st_summarystats(ST_Union(a.rast))
FROM adamiak.paranhos_dem AS a;

--Przyklad 7
WITH t AS (
SELECT st_summarystats(ST_Union(a.rast)) AS stats
FROM adamiak.paranhos_dem AS a
)
SELECT (stats).min,(stats).max,(stats).mean FROM t;

--Przyklad 8
WITH t AS (
SELECT b.parish AS parish, st_summarystats(ST_Union(ST_Clip(a.rast,
b.geom,true))) AS stats
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
group by b.parish
)
SELECT parish,(stats).min,(stats).max,(stats).mean FROM t;

--Przyklad 9
SELECT b.name,st_value(a.rast,(ST_Dump(b.geom)).geom)
FROM
rasters.dem a, vectors.places AS b
WHERE ST_Intersects(a.rast,b.geom)
ORDER BY b.name;

--Przyklad 10
create table adamiak.tpi30 as
select ST_TPI(a.rast,1) as rast
from rasters.dem a;

CREATE INDEX idx_tpi30_rast_gist ON adamiak.tpi30
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('adamiak'::name,
'tpi30'::name,'rast'::name);

--QGIS

--Algebra map
--Przyklad 1
CREATE TABLE adamiak.porto_ndvi AS
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, 1,
r.rast, 4,
'([rast2.val] - [rast1.val]) / ([rast2.val] +
[rast1.val])::float','32BF'
) AS rast
FROM r;

CREATE INDEX idx_porto_ndvi_rast_gist ON adamiak.porto_ndvi
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('adamiak'::name,
'porto_ndvi'::name,'rast'::name);

--Przyklad 2
create or replace function adamiak.ndvi(
value double precision [] [] [],
pos integer [][],
VARIADIC userargs text []
)
RETURNS double precision AS
$$
BEGIN
--RAISE NOTICE 'Pixel Value: %', value [1][1][1];-->For debug purposes 
RETURN (value [2][1][1] - value [1][1][1])/(value [2][1][1]+value
[1][1][1]); --> NDVI calculation!
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE COST 1000;

CREATE TABLE adamiak.porto_ndvi2 AS
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, ARRAY[1,4],
'adamiak.ndvi(double precision[],
integer[],text[])'::regprocedure, --> This is the function!
'32BF'::text
) AS rast
FROM r;

CREATE INDEX idx_porto_ndvi2_rast_gist ON adamiak.porto_ndvi2
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('adamiak'::name,
'porto_ndvi2'::name,'rast'::name);

--Przyklad 3
--MapAlgebra

--Eksport Danych
--Przyklad 1
SELECT ST_AsTiff(ST_Union(rast))
FROM adamiak.porto_ndvi;

--Przyklad 2
SELECT ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE',
'PREDICTOR=2', 'PZLEVEL=9'])
FROM adamiak.porto_ndvi;

SELECT ST_GDALDrivers();

-- CREATE TABLE tmp_out AS
-- SELECT lo_from_bytea(0,
--  ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE',
-- 'PREDICTOR=2', 'PZLEVEL=9'])
--  ) AS loid
-- FROM adamiak.porto_ndvi;
-- ----------------------------------------------
-- SELECT lo_export(loid, 'G:\myraster.tiff') --> Save the file in a place
-- where the user postgres have access. In windows a flash drive usualy works
-- fine.
--  FROM tmp_out;
-- ----------------------------------------------
-- SELECT lo_unlink(loid)
--  FROM tmp_out; --> Delete the large object.

--Rozwiazanie problemu
create table adamiak.tpi30_porto as
SELECT ST_TPI(a.rast,1) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto'

CREATE INDEX idx_tpi30_porto_rast_gist ON adamiak.tpi30_porto
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('adamiak'::name,
'tpi30_porto'::name,'rast'::name);
