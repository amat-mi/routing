--1. GROUP STOPS BY GEOMETRY AND TRANSFORM STOPS FROM 4326 TO 3003 
--   raggruppare le fermate serve per spezzare il grafo. 
--   ad ogni fermata viene associato il modo di trasporto

-- TABELLE INPUT:
-- 1. adb.web_stops

-- TABELLA OUTPUT:
-- 1. adb.web_01_fermate

DROP TABLE adb.web_01_fermate;
CREATE TABLE adb.web_01_fermate AS 

--verifica dei route_type presenti in db

  SELECT 
    ROW_NUMBER() OVER(ORDER BY geom) AS stop_id, route_type, ARRAY_AGG(stop_id) stop_id_originali,  geom
  FROM adb.web_stops
  GROUP BY geom, route_type;

-- 2. crea uno SPATIAL INDEX sulla tabella delle fermate per accelerare le query

CREATE INDEX web_01_fermate_idx ON adb.web_01_fermate USING GIST (geom);
