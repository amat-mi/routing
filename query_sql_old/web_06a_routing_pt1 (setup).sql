-- PROCEDURA ROUTING
-- N.B. IL ROUTING VIENE FATTO SOLO SUI RECORD "CORRETTI" (18:23 hours all!)

-- TABELLE INPUT:
-- 1. adb.web_04_stops (SOLO QUELLI CORRETTI)
-- 2. adb.web_02_grafo per gli archi senza geometria esitente (geom_check=0)
-- 3. adb.web_02_grafo_vertices_pgr
-- 4. adb.web_05_grafo per gli archi con geometria esitente (geom_check=1)

-- TABELLA OUTPUT:
-- 1. adb.web_06_routing (popolata)

-- 1. CREA TABELLA DI APPOGGIO IN CUI INSERIRE I RISULTATI DEL ROUTING
/*
CREATE TABLE adb.web_06_routing
(
  nodo_partenza integer,
  nodo_arrivo integer,
  stop_partenza integer,
  stop_arrivo integer,
  line_id text,
  geom_check integer,
  contatore integer,
  seq integer,
  id1 integer,
  id2 integer,
  cost double precision
);

*/
--APPOGGIO TEMP 

CREATE TABLE adb.t_web_04_stops AS 
(
SELECT route_type, stop_id_s, stop_id_e, stop_code_s, stop_code_e, line_id, 
       line_code, ST_TRANSFORM(geom, 3003) geom, geom_check, nodo_partenza, nodo_arrivo, contatore, 
       corretto
  FROM adb.web_04_stops

);

CREATE INDEX t_web_04_stops_idx
  ON adb.t_web_04_stops
  USING gist
  (geom);

CREATE TABLE adb.t_web_02_grafo_vertices_pgr AS 
(
SELECT id, cnt, chk, ein, eout, ST_TRANSFORM(the_geom, 3003) the_geom
  FROM adb.web_02_grafo_vertices_pgr
);

CREATE INDEX t_web_02_grafo_vertices_pgr_idx
  ON adb.t_web_02_grafo_vertices_pgr
  USING gist
  (the_geom);


CREATE TABLE adb.t_web_02_grafo AS 
(
SELECT route_type, id_new, id_originale, way_originale, source_old, target_old, 
       oneway, bus, cost, rcost, way_modificato, usare, ST_TRANSFORM(geom, 3003)  geom, source, 
       target
  FROM adb.web_02_grafo
);

CREATE INDEX t_web_02_grafo_idx
  ON adb.t_web_02_grafo
  USING gist
  (geom);


CREATE TABLE adb.t_web_05_grafo AS 
(
SELECT route_type, id_new, id_originale, way_originale, source, target, oneway, 
       bus, cost, rcost, way_modificato, usare, geom_check, contatore, 
       ST_TRANSFORM(geom, 3003) geom
  FROM adb.web_05_grafo
);


CREATE INDEX t_web_05_grafo_idx
  ON adb.t_web_05_grafo
  USING gist
  (geom);


-- 1.RESET TABELLA DI OUTPUT
DELETE FROM adb.web_06_routing;



