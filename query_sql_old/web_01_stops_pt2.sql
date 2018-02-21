-- PER ACCELERARE LA PROCEDURA, CREATO UN CAMPO "GEOM_BUFF" --> perche cosi nella query successiva posso utilizzare && (che co i ounti puo creare un problema)

-- TABELLE INPUT:
-- 1. adb.web_01_fermate

-- TABELLA OUTPUT:
-- 1. adb.web_01_fermate_buffer

DROP TABLE adb.web_01_fermate_buffer;
CREATE TABLE adb.web_01_fermate_buffer AS 
SELECT  
  stop_id, ST_TRANSFORM(ST_BUFFER(ST_TRANSFORM (geom,3003), 240),4326) geom_buff,  route_type, geom 
FROM adb.web_01_fermate;

CREATE INDEX web_01_fermate_buffer_idx ON adb.web_01_fermate_buffer USING GIST (geom)
