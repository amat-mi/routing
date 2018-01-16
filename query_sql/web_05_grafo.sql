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


