-- ASSOCIA LE FERMATE AL NODO CORRISPONDENTE

-- TABELLE INPUT:
-- 1. adb.web_01_fermate
-- 2. adb.web_02_grafo_vertices_pgr

-- TABELLA OUTPUT:
-- 1. adb.web_03_fermate_nodo


--WITH 

CREATE TABLE  adb.t_nodo_route_type as (
	--obiettivo: recuperare l'identificativo di route_type, che mi serve per associare la fermata all'arco corretto
	SELECT DISTINCT source as id , route_type FROM adb.web_02_grafo
	UNION
	SELECT DISTINCT target as id , route_type FROM adb.web_02_grafo);


CREATE TABLE  adb.t_vertici as (
	SELECT id, route_type, cnt, chk, ein, eout, ST_TRANSFORM(the_geom, 3003) as the_geomt
	FROM adb.web_02_grafo_vertices_pgr
		JOIN adb.t_nodo_route_type USING (id));

CREATE INDEX t_vertici_idx
  ON adb.t_vertici
  USING gist
  (the_geomt);

CREATE TABLE  adb.t_fermate as (SELECT *, ST_TRANSFORM(geom, 3003) as geomt FROM adb.web_01_fermate );
CREATE INDEX t_fermate_idx
  ON adb.t_fermate
  USING gist
  (geomt);

DROP TABLE adb.web_03_fermate_nodo;

CREATE TABLE adb.web_03_fermate_nodo  AS(
  SELECT DISTINCT ON (a.stop_id) a.stop_id, stop_id_originali,
    b.id AS id_nodo,  
    ST_TRANSFORM(b.the_geomt,4326) AS geom,
    a.route_type
  FROM adb.t_vertici AS b
  INNER JOIN   adb.t_fermate a
  ON
    ST_DWithin(a.geomt, b.the_geomt, 50) and a.route_type = b.route_type

  ORDER BY a.stop_id, ST_Distance(b.the_geomt, a.geomt)) ;
 
-- 2. CREA SPATIAL INDEX
CREATE INDEX web_03_fermate_nodo_idx ON adb.web_03_fermate_nodo USING GIST (geom);


--9.ELIMINO TABELLE TEMPORANEE
DROP TABLE adb.t_nodo_route_type;
DROP TABLE adb.t_vertici;
DROP TABLE adb.t_fermate;
