-- a questo punto dobbiamo creare l'ultima tabella utile per il ROUTING (abbiamo gia creato "adb.web_02_grafo" e "adb.web_04_stops")
-- bisogna CREARE IL GRAFO PER LE "LINE_ID" CHE HANNO LA "GEOM_CHECK"=1

-- TABELLE INPUT:
-- 1. adb.web_04_stops
-- 2. adb.web_02_grafo

-- TABELLA OUTPUT:
-- 1. adb.web_05_grafo

CREATE TABLE adb.web_05_grafo AS 
-- 1. seleziona i record sui quali bisogna fare la procedura delle LINES 
WITH lines AS (
  SELECT 
    stop_id_s, stop_id_e, stop_code_s, stop_code_e, line_id, line_code, 
    geom_check, nodo_partenza, nodo_arrivo, contatore, ST_TRANSFORM(geom, 3003) AS geom 
  FROM 
    adb.web_04_stops
  WHERE
    geom_check=1
),

-- 2. CREATE A BUFFER AROUND THE LINES
lines_buffer AS(
  SELECT 
    stop_id_s, stop_id_e, stop_code_s, stop_code_e, line_id, line_code, contatore, ST_BUFFER(geom,200) AS geom, geom_check
  FROM 
    lines
),

-- 4. INTERSECT "LINES_BUFFER" CON IL GRAFO
grafo_buffer AS (
  SELECT 
    b.id_new, b.id_originale, b.way_originale, b.source, b.target, b.oneway, b.bus, b.cost, b.rcost, b.way_modificato, b.usare, 
    geom_check, contatore, b.geom
  FROM 
    lines_buffer a,
    adb.web_02_grafo b
  WHERE
    a.geom && b.geom AND
    ST_INTERSECTS(a.geom, b.geom)
)

SELECT * 
FROM grafo_buffer;

-- 4. CREA SPATIAL INDEX
CREATE INDEX web_05_grafo_idx ON adb.web_05_grafo USING GIST (geom);
-- a questo punto dobbiamo creare l'ultima tabella utile per il ROUTING (abbiamo gia creato "adb.web_02_grafo" e "adb.web_04_stops")
-- bisogna CREARE IL GRAFO PER LE "LINE_ID" CHE HANNO LA "GEOM_CHECK"=1

-- TABELLE INPUT:
-- 1. adb.web_04_stops
-- 2. adb.web_02_grafo

-- TABELLA OUTPUT:
-- 1. adb.web_05_grafo

-- 1. seleziona i record sui quali bisogna fare la procedura delle LINES 
CREATE TABLE adb.t_lines AS (
  SELECT 
    route_type, stop_id_s, stop_id_e, stop_code_s, stop_code_e, line_id, line_code, 
    geom_check, nodo_partenza, nodo_arrivo, contatore, ST_TRANSFORM(geom, 3003) AS geom 
  FROM 
    adb.web_04_stops
  WHERE
    geom_check=1
);

CREATE INDEX t_lines_idx ON adb.t_lines USING GIST (geom);


-- 2. CREATE A BUFFER AROUND THE LINES
CREATE TABLE adb.t_lines_buffer AS(
  SELECT 
    route_type, stop_id_s, stop_id_e, stop_code_s, stop_code_e, line_id, line_code, contatore, ST_BUFFER(geom,200) AS geom, geom_check
  FROM 
    adb.t_lines
);

CREATE INDEX t_lines_buffer_idx ON adb.t_lines_buffer USING GIST (geom);

--SELECT * FROM lines_buffer
--3.GRAFO
CREATE TABLE adb.t_grafo as (
SELECT route_type, id_new, id_originale, way_originale, source_old, target_old, 
       oneway, bus, cost, rcost, way_modificato, usare, ST_TRANSFORM(geom, 3003) AS geom, source, 
       target
  FROM adb.web_02_grafo);
CREATE INDEX t_grafo_idx ON adb.t_grafo USING GIST (geom);

-- 4. INTERSECT "LINES_BUFFER" CON IL GRAFO
CREATE TABLE adb.t_grafo_buffer AS (
  SELECT 
    a.route_type, b.id_new, b.id_originale, b.way_originale, b.source, b.target, b.oneway, b.bus, b.cost, b.rcost, b.way_modificato, b.usare, 
    geom_check, contatore, ST_TRANSFORM(b.geom, 4326) as geom --b.geom 
    --geom_check, contatore, b.geom, 4326 --b.geom 
  FROM 
    adb.t_lines_buffer a,
    --adb.web_02_grafo b
    adb.t_grafo b
  WHERE
    a.geom && b.geom AND
    ST_INTERSECTS(a.geom, b.geom) AND 
    a.route_type = b.route_type
);
CREATE INDEX t_grafo_buffer_idx ON adb.t_grafo_buffer USING GIST (geom);

DROP TABLE adb.web_05_grafo;
CREATE TABLE adb.web_05_grafo AS (

SELECT *
FROM adb.t_grafo_buffer );

-- 4. CREA SPATIAL INDEX
CREATE INDEX web_05_grafo_idx ON adb.web_05_grafo USING GIST (geom);

DROP TABLE adb.t_lines;
DROP TABLE adb.t_lines_buffer;
DROP TABLE adb.t_grafo;
DROP TABLE adb.t_grafo_buffer;

