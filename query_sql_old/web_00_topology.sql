-- CREA TOPOLOGIA 

-- TABELLE INPUT:
-- 1. adb.web_00_grafo

-- TABELLA OUTPUT:
-- 1. adb.web_00_grafo (source e target)
-- 2. adb.web_00_grafo_vertices_pgr

-- 1. aggiungi SOURCE and TARGET per NODI
ALTER TABLE adb.web_00_grafo
ADD COLUMN source integer;

ALTER TABLE adb.web_00_grafo
ADD COLUMN target integer;

-- 2. CREA TOPOLGY
SELECT pgr_createTopology('adb.web_00_grafo', 0.000001,  'geom', 'id');
