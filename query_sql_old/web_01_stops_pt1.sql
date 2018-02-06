--1. GROUP STOPS BY GEOMETRY AND TRANSFORM STOPS FROM 4326 TO 3003 
--   raggruppare le fermate serve per spezzare il grafo. 

-- TABELLE INPUT:
-- 1. adb.web_stops

-- TABELLA OUTPUT:
-- 1. adb.web_01_fermate


CREATE TABLE adb.web_01_fermate AS 
  SELECT 
    ROW_NUMBER() OVER(ORDER BY geom) AS stop_id, ARRAY_AGG(stop_id) stop_id_originali, ST_TRANSFORM(geom, 3003) geom
  FROM adb.web_stops
  GROUP BY geom;

-- 2. crea uno SPATIAL INDEX sulla tabella delle fermate per accelerare le query
CREATE INDEX web_01_fermate_idx ON adb.web_01_fermate USING GIST (geom);  