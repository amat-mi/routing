-- PROCEDURA ROUTING
-- N.B. IL ROUTING VIENE FATTO SOLO SUI RECORD "CORRETTI" (18:23 hours all!)

-- TABELLE INPUT:
-- 1. adb.web_04_stops (SOLO QUELLI CORRETTI)
-- 2. adb.web_02_grafo
-- 3. adb.web_02_grafo_vertices_pgr

-- TABELLA OUTPUT:
-- 1. adb.web_06_routing (popolata)

-- 1. CREA TABELLA DI APPOGGIO PER IL ROUTING
/*
CREATE TABLE adb.web_06_routing
(
  nodo_partenza integer,
  nodo_arrivo integer,
  stop_partenza integer,
  stop_arrivo integer,
  line_id text,
  geom_check integer,
  contatore integer,
  seq integer,
  id1 integer,
  id2 integer,
  cost double precision
);
*/

-- 2. ROUTING
DO
$do$
DECLARE
    i bigint;
BEGIN
FOR i IN SELECT contatore FROM adb.web_04_stops WHERE corretto=1 ORDER BY contatore LOOP 
   INSERT INTO adb.web_06_routing (nodo_partenza, nodo_arrivo, stop_partenza, stop_arrivo, line_id, geom_check, contatore, seq, id1, id2, cost) -- use col names
   SELECT
     (SELECT nodo_partenza FROM adb.web_04_stops WHERE contatore=i) AS nodo_partenza,
     (SELECT nodo_arrivo FROM adb.web_04_stops WHERE contatore=i) AS nodo_arrivo,
     (SELECT stop_id_s FROM adb.web_04_stops WHERE contatore=i) AS stop_partenza,
     (SELECT stop_id_e FROM adb.web_04_stops WHERE contatore=i) AS stop_arrivo,
     (SELECT line_id FROM adb.web_04_stops WHERE contatore=i) AS line_id,
     (SELECT geom_check FROM adb.web_04_stops WHERE contatore=i) AS geom_check,
     (SELECT contatore FROM adb.web_04_stops WHERE contatore=i) AS geom_check,
     seq, id1, id2, cost
  FROM pgr_bdDijkstra(  
    'SELECT 
      id_new::integer AS id,
      source,
      target, 
      cost::float8, 
      rcost::float8 AS reverse_cost 
    FROM 
      (SELECT 
         b.id_new, b.source, b.target, b.cost, b.rcost, 0 geom_check, b.geom 
       FROM 
         adb.web_02_grafo b
       WHERE       
         usare=1 AND
         b.geom && 
         (SELECT ST_Expand(st_collect(the_geom), 4000) 
         FROM 
           (SELECT * FROM adb.web_04_stops WHERE contatore='||i||')a,
           adb.web_02_grafo_vertices_pgr b  
         WHERE
           a.nodo_partenza=b.id OR
           a.nodo_arrivo=b.id)

      UNION

      SELECT 
        id_new, source, target, cost, rcost, geom_check, geom 
      FROM adb.web_05_grafo
      WHERE 
      usare=1 AND contatore='||i||') a
    WHERE
      -- FILTRA su ways con source e target not null (hanno st_geometry=point). Errore originato quando lanciata la topologia su adb.web_02_grafo 
      (source IS NOT NULL OR target IS NOT NULL) AND 
      --
      geom_check=(SELECT geom_check FROM adb.web_04_stops WHERE contatore='||i||')
    ',
     (SELECT nodo_partenza FROM adb.web_04_stops WHERE contatore=i), 
     (SELECT nodo_arrivo FROM adb.web_04_stops WHERE contatore=i),
    -- BOTH PARAMETER SET TO TRUE FOR ONEWAY STREETS 
    TRUE,
    TRUE);
END LOOP;
END
$do$