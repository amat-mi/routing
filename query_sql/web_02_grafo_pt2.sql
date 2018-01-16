-- CREA TOPOLOGIA 

-- TABELLE INPUT:
-- 1. adb.web_02_grafo

-- TABELLA OUTPUT:
-- 1. adb.web_02_grafo (source e target)
-- 2. adb.web_02_grafo_vertices_pgr

-- 1. aggiungi SOURCE and TARGET per NODI
ALTER TABLE adb.web_02_grafo
ADD COLUMN source integer;

ALTER TABLE adb.web_02_grafo
ADD COLUMN target integer;

-- 2. CREA TOPOLGY
SELECT pgr_createTopology('adb.web_02_grafo', 0.0001, 'geom', 'id_new');
