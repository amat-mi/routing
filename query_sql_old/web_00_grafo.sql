
--------------- 1

CREATE TABLE adb.t_nodi AS (

WITH grafo AS (
  SELECT id, version, user_id, tstamp, changeset_id, tags, nodes, bbox, linestring as geom, route_type, varcosto
  FROM adb.web_000_grafo_costi 
)

SELECT
      id, node_id, dist, pos, geom_line, verifica ,route_type,  varcosto,
     ROW_NUMBER() OVER(PARTITION BY id,route_type ORDER BY dist) AS rownum
  FROM 
  (
    SELECT
      a.id, b.node_id, b.sequence_id, 
      (ST_Length(a.geom)*ST_LineLocatePoint(ST_GeometryN(a.geom,1), c.geom)) AS dist, 
      (ST_Length(a.geom)*ST_LineLocatePoint(ST_GeometryN(a.geom,1), c.geom))/ST_LENGTH(a.geom) AS pos, 
      a.geom AS geom_line, c.geom AS geom_point,a.route_type,  a.varcosto,
      CASE WHEN sequence_id>0 AND (ST_Length(a.geom)*ST_LineLocatePoint(ST_GeometryN(a.geom,1), c.geom))=0 THEN 1 ELSE 0 END AS verifica

    FROM
      grafo a, 
      adb.cart_osm_way_nodes b,
      adb.cart_osm_nodes c
    WHERE
      a.geom && c.geom AND
      a.id = b.way_id AND
      b.node_id = c.id
     --AND (CASE WHEN sequence_id>0 AND (ST_Length(a.geom)*ST_LineLocatePoint(ST_GeometryN(a.geom,1), c.geom))=0 THEN 1 ELSE 0 END)=0 
  )a
  WHERE verifica = 0 
  GROUP BY
    id, node_id, dist, pos,geom_line, verifica, route_type, varcosto) ;
------------------------------------------------    

CREATE INDEX t_nodi_idx ON adb.t_nodi USING GIST (geom_line);

-- 2. PER GLI ARCHI CHE SI CHIUDONO (ad esempio le rotonde che hanno start_point=end_point)

CREATE TABLE adb.t_nodi_fine AS (

  SELECT 
    a.id, a.node_id, a.dist,a.route_type, a.varcosto,
    CASE 
      WHEN b.id IS NULL THEN a.pos
      WHEN (b.id>0 AND a.pos=0) THEN 1
      ELSE 1
    END AS pos,
    a.rownum, a.geom_line
  FROM
    adb.t_nodi a LEFT JOIN (SELECT id, MAX(rownum) AS rownum FROM adb.t_nodi GROUP BY id)b ON a.id=b.id AND a.rownum=b.rownum
  ORDER BY a.id
);
---------------------------------
CREATE INDEX t_nodi_fineidx ON adb.t_nodi_fine USING GIST (geom_line);



-- 3. CONTROLLA SE GLI ARCHI SI CHIUDONO (ROTONDE)

CREATE TABLE adb.t_linea_chiusa AS 
(SELECT 
    a.id,
    CASE WHEN a.pos=b.pos THEN 0 ELSE 1 END AS linea_chiusa, 
    a.rownum AS rownum_max, a.route_type, a.varcosto
  FROM 
    (SELECT  id, MAX(pos)pos, MAX(rownum) rownum, route_type, varcosto  FROM adb.t_nodi GROUP BY  id,route_type, varcosto) a, 
    (SELECT id, MAX(pos)pos, MAX(rownum) rownum, route_type FROM adb.t_nodi_fine GROUP BY route_type,  id) b
  WHERE
    a.id=b.id AND a.rownum=b.rownum);



    -- 4. SE LA LINEA E' CHIUSA (start_point=end_point) BISOGNA AGGIUNGERE UN PUNTO: IL PUNTO CON 'POS=0' DIVENTA ANCHE IL PUNTO CON 'POS=1' 

CREATE TABLE adb.t_nodi_all AS 
(
  -- nodi_fine
  SELECT  id, node_id, dist, pos, rownum, geom_line, route_type, varcosto
  FROM adb.t_nodi

  UNION 
  
  -- linea chiusa: aggiungi un nodo. Il nodo con'pos=0' diventa anche il nodo con 'pos=1'
  SELECT
     a.id, a.node_id, a.dist, 1 AS pos, (rownum_max+1) AS rownum, geom_line, a.route_type, a.varcosto
  FROM
    adb.t_nodi_fine a,
    adb.t_linea_chiusa b
  WHERE
    a.id=b.id and a.route_type = b.route_type AND linea_chiusa=1 AND pos=0
);
CREATE INDEX t_nodi_all_idx ON adb.t_nodi_all USING GIST (geom_line);

-- 5. SPEZZA GLI ARCHI DOVE CI SONO I NODI
CREATE TABLE adb.t_spezza_archi AS (
  SELECT 
    ROW_NUMBER() OVER(ORDER BY a.id, a.route_type) AS id, a.id AS way_originale, a.node_id AS node_start, b.node_id AS node_end, a.rownum as rownum1, b.rownum as rownum2,
    ST_LineSubstring(a.geom_line, a.pos, b.pos) AS geom   ,a.route_type, a.varcosto
  FROM 
    adb.t_nodi_all a, adb.t_nodi_all b 
  WHERE 
    a.id=b.id AND
    a.rownum=(b.rownum-1) AND 
    a.route_type = b.route_type 
);

CREATE INDEX t_spezza_archi_idx ON adb.t_spezza_archi USING GIST (geom);

-- 6.IMPOSTA CAMPO BUS(0,1) E ONEWAY(0,1), REVERSE(0,1)
DROP TABLE adb.t_bus_oneway ;
CREATE TABLE adb.t_bus_oneway AS ( 
WITH grafo AS (
  SELECT id, version, user_id, tstamp, changeset_id, tags, nodes, bbox, linestring as geom, route_type, varcosto
  FROM adb.web_000_grafo_costi 
)


  SELECT 
     id, version, user_id, tstamp, changeset_id, tags, nodes, bbox, geom, route_type,varcosto,
    -- campo oneway (1:yes, 0:no)
    CASE
	WHEN w.tags -> 'oneway:bus'='no' THEN 0
	WHEN defined(w.tags, 'psv'::text)  THEN 0
	WHEN w.tags -> 'psv:lanes:backward'='yes'  THEN 0
	WHEN w.tags -> 'oneway:bus'='no' THEN 0  
      WHEN w.tags -> 'oneway'='yes' THEN 1
      WHEN w.tags -> 'oneway'='-1' THEN 1
      WHEN w.tags -> 'junction'='roundabout' THEN 1
      WHEN w.tags -> 'highway'='motorway' THEN 1
      
      /*WHEN w.tags -> 'psv' = "yes" THEN 0
      WHEN w.tags -> 'psv' = "opposite_lane" THEN 0
      WHEN w.tags -> 'psv' = "opposite" THEN 0
      WHEN w.tags -> 'psv' = "opposite_track" THEN 0*/
      
      
      ELSE 0
    END AS oneway,
    
    -- campo percorrenza bus (1:yes, 0:no)
    CASE
      WHEN defined(w.tags,'bus') and w.tags -> 'bus' in ('no') THEN 0 
      ELSE 1
    END AS bus,
    
    -- geom disegnata nel verso opposto (1:yes, 0:no)
    CASE WHEN (tags -> 'oneway'='-1') THEN 1 ELSE 0 END AS reverse
  FROM 
    grafo w 
);

CREATE INDEX t_bus_oneway_idx ON adb.t_bus_oneway USING GIST (geom);

-- 6. FINE: associa al nuovo grafo le informazione su ONEWAY, BUS, REVERSE
DROP TABLE adb.web_00_grafo;
CREATE TABLE adb.web_00_grafo AS (
SELECT 
   a.id, a.way_originale, a.node_start, a.node_end, 
   b.version, b.tags, b.bus, b.oneway, b.reverse,
    a.geom, a.route_type, a.varcosto
FROM
  adb.t_spezza_archi a JOIN adb.t_bus_oneway b ON a.way_originale=b.id and a.route_type = b.route_type
ORDER BY a.way_originale);

-- 7. crea uno SPATIAL INDEX sulla tabella delle grafo per accelerare le query
CREATE INDEX web_00_grafo_idx ON adb.web_00_grafo USING GIST (geom);



DROP TABLE adb.t_nodi;
DROP TABLE adb.t_nodi_fine;
DROP TABLE adb.t_linea_chiusa;
DROP TABLE adb.t_nodi_all; 
DROP TABLE adb.t_spezza_archi; 
DROP TABLE adb.t_bus_oneway;



-- 8. PERMESSI DI L/S
--ALTER TABLE adb.web_00_grafo
GRANT SELECT ON TABLE adb.web_00_grafo TO adb_l;

--9.CONTROLLI
--ID DOPPI SU OUTPUT
SELECT 'ID_DOPPI' as err, id, count(id)
  FROM adb.web_00_grafo
  GROUP BY err, id
  HAVING count(id) > 1 ;

