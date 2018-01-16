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


/*
WITH grafo_routing AS (
  SELECT
    a.id, a.way_old, a.source, a.target, a.oneway, a.bus, a.cost, a.rcost, x1, y1, ST_X(b.the_geom) AS x2, ST_Y(b.the_geom) AS y2, 
    a.geom
  FROM
    (SELECT
      a.id, a.way_old, a.source, a.target, a.oneway, a.bus, a.cost, a.rcost, 
      ST_X(b.the_geom) AS x1, ST_Y(b.the_geom) AS y1,
      a.geom
    FROM
      adb.osm_1_grafo a,
      adb.osm_1_grafo_vertices_pgr b
    WHERE
      a.source=b.id)a,
    adb.osm_1_grafo_vertices_pgr b
  WHERE
    a.target=b.id
)

SELECT * FROM grafo_routing 
*/