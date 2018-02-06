-- PER ACCELERARE LA PROCEDURA, CREATO UN CAMPO "GEOM_BUFF" --> perche cosi nella query successiva posso utilizzare && (che co i ounti puo creare un problema)

-- TABELLE INPUT:
-- 1. adb.web_01_fermate

-- TABELLA OUTPUT:
-- 1. adb.web_01_fermate_buffer


CREATE TABLE adb.web_01_fermate_buffer AS 
SELECT  
  stop_id, ST_BUFFER(geom,240) geom_buff, geom 
FROM adb.web_01_fermate;

CREATE INDEX web_01_fermate_buffer_idx ON adb.web_01_fermate_buffer USING GIST (geom)