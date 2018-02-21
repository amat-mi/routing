-- PROCEDURA ROUTING
-- N.B. IL ROUTING VIENE FATTO SOLO SUI RECORD "CORRETTI" (18:23 hours all!)
-- CONVIENE ESEGUIRE IN PARALLELO, SPEZZANDO QUESTO SCRIPT IN "BLOCCHI" DA 1000 contatori (in questo script, andando da 0 a 100000, vengono considerati tutti

-- TABELLE INPUT:
-- 1. adb.t_web_04_stops (SOLO QUELLI CORRETTI)
-- 2. adb.t_web_02_grafo per gli archi senza geometria esitente (geom_check=0)
-- 3. adb.t_web_02_grafo_vertices_pgr
-- 4. adb.t_web_05_grafo per gli archi con geometria esitente (geom_check=1)

-- TABELLA OUTPUT:
-- 1. adb.web_06_routing (popolata)

-- 2. ROUTING

DO
$do$
DECLARE
    i bigint;
    j text;
BEGIN
FOR j IN SELECT route_type FROM adb.t_web_04_stops GROUP BY route_type LOOP   --selezione dei modi usati. non c'è modo di inserire direttamente la listA?
	FOR i IN SELECT contatore FROM adb.t_web_04_stops WHERE corretto=1  and route_type = j   and contatore >= 0 and contatore < 1000000 ORDER BY contatore LOOP  -- i filtri sul contatore sono solo per debug 

	   RAISE notice 'contatore: % inizio', i ;
	   INSERT INTO adb.web_06_routing (route_type, nodo_partenza, nodo_arrivo, stop_partenza, stop_arrivo, line_id, geom_check, contatore, seq, id1, id2, cost) -- use col names
	   SELECT
	     (SELECT route_type FROM adb.t_web_04_stops WHERE contatore=i and route_type = j ) AS route_type,
	     (SELECT nodo_partenza FROM adb.t_web_04_stops WHERE contatore=i and route_type = j ) AS nodo_partenza,
	     (SELECT nodo_arrivo FROM adb.t_web_04_stops WHERE contatore=i and route_type = j ) AS nodo_arrivo,
	     (SELECT stop_id_s FROM adb.t_web_04_stops WHERE contatore=i and route_type = j ) AS stop_partenza,
	     (SELECT stop_id_e FROM adb.t_web_04_stops WHERE contatore=i and route_type = j ) AS stop_arrivo,
	     (SELECT line_id FROM adb.t_web_04_stops WHERE contatore=i and route_type = j ) AS line_id,
	     (SELECT geom_check FROM adb.t_web_04_stops WHERE contatore=i and route_type = j ) AS geom_check,
	     (SELECT contatore FROM adb.t_web_04_stops WHERE contatore=i and route_type = j ) AS geom_check, --doppio?
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
		 b.id_new, b.source, b.target, b.cost, b.rcost, 0 geom_check,  b.geom 
	       FROM 
		 adb.t_web_02_grafo b
	       WHERE 
	         usare=1 AND
		 b.geom && 
		 (SELECT ST_Expand(st_collect(the_geom), 4000) 
		 FROM 
		   (SELECT * FROM adb.t_web_04_stops WHERE  contatore='||i||' and route_type = '||j||')a,
		   adb.t_web_02_grafo_vertices_pgr b  
		 WHERE
		   a.nodo_partenza=b.id OR
		   a.nodo_arrivo=b.id)

	      UNION

	      SELECT 
		id_new, source, target, cost, rcost, geom_check, geom 
	      FROM adb.t_web_05_grafo
	      WHERE 
	      usare=1 AND contatore='||i||' and route_type = '||j||' ) a
	    WHERE
	      -- FILTRA su ways con source e target not null (hanno st_geometry=point). Errore originato quando lanciata la topologia su adb.t_web_02_grafo 
	      (source IS NOT NULL OR target IS NOT NULL) AND 
	      --
	      geom_check=(SELECT geom_check FROM adb.t_web_04_stops WHERE contatore='||i||' and route_type = '||j||')
	    ',
	     (SELECT nodo_partenza FROM adb.t_web_04_stops WHERE contatore=i and route_type = j), 
	     (SELECT nodo_arrivo FROM adb.t_web_04_stops WHERE contatore=i and route_type = j),
	    -- BOTH PARAMETER SET TO TRUE FOR ONEWAY STREETS 
	    TRUE,
	    TRUE);
	END LOOP;
 END LOOP;
END
$do$
