-- ASSOCIA LE FERMATE AL NODO CORRISPONDENTE

-- TABELLE INPUT:
-- 1. adb.web_01_fermate
-- 2. adb.web_02_grafo_vertices_pgr

-- TABELLA OUTPUT:
-- 1. adb.web_03_fermate_nodo


CREATE TABLE adb.web_03_fermate_nodo AS
  SELECT DISTINCT ON(a.stop_id) a.stop_id, stop_id_originali,
    b.id AS id_nodo,  
    b.the_geom AS geom
  FROM
    adb.web_02_grafo_vertices_pgr AS b
  INNER JOIN
    adb.web_01_fermate a
  ON
    ST_DWithin(a.geom, b.the_geom, 300) 
  ORDER BY a.stop_id, ST_Distance(b.the_geom, a.geom);


-- 2. CREA SPATIAL INDEX
CREATE INDEX web_03_fermate_nodo_idx ON adb.web_03_fermate_nodo USING GIST (geom)
