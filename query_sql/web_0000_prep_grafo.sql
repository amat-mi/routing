-- GRAFO OSM (spezzare il grafo OSM dove ci sono i nodi OSM)

-- INPUT:
-- 1. osm_views.auto_ways  
-- 2. osm_views.pinf_ways_piedi
-- 3. public.way_nodes
-- 4. public.nodes

-- OUTPUT:
-- 1. osm_views.web_00_grafo


-- UNISCI AL GRAFO DELLE AUTO I RECORD CHE SONO IMPUTATI IN OSM COME PEDONALI, MA SUI QUALI IN REALTA PASSANO GLI AUTOBUS 
CREATE TABLE osm_views.web_00_grafo AS -- DA IMPORTARE POI IN "ADB"
WITH grafo AS (
  -- GRAFO AUTO
  SELECT id, version, user_id, tstamp, changeset_id, tags, nodes, bbox, linestring AS geom FROM osm_views.pinf_ways_auto
  -- SELECT * FROM osm_views.auto_ways 

  UNION

  -- GRAFO TRAM (imputato nella tabella degli archi a piedi)
  SELECT * FROM osm_views.pinf_ways_piedi w
  WHERE w.tags -> 'railway'='tram' 

  UNION

  -- GRAFO PIEDI (dove ci sono errori - archi dove ci possono passare anche le auto -)
  SELECT * FROM osm_views.pinf_ways_piedi
  WHERE 
    id=72889775 OR id=437268493 OR id=417065628 OR id=337622947 OR id=184207162 OR id=278242130 OR id=23449144 OR id=158183080 OR
    id=332413475 OR id=27854539 OR id=316197534 OR id=316197537 OR id=331312071 OR id=48121606	
),

-- DISTANZA DEL NODO DAL NODO DI PARTENZA ed ELIMINA EVENTUALI ERRORI DI POS (es.contatore=996
nodi AS (
  SELECT
     id, node_id, dist, pos, geom_line, verifica,
     ROW_NUMBER() OVER(PARTITION BY id ORDER BY dist) AS rownum
  FROM 
  (
    SELECT
      a.id, b.node_id, b.sequence_id, 
      (ST_Length(a.geom::geography)*ST_LineLocatePoint(ST_GeometryN(a.geom,1), c.geom)) AS dist, 
      (ST_Length(a.geom::geography)*ST_LineLocatePoint(ST_GeometryN(a.geom,1), c.geom))/ST_LENGTH(a.geom::geography) AS pos, 
      a.geom AS geom_line, c.geom AS geom_point,
      CASE WHEN sequence_id>0 AND (ST_Length(a.geom::geography)*ST_LineLocatePoint(ST_GeometryN(a.geom,1), c.geom))=0 THEN 1 ELSE 0 END AS verifica
    FROM
      grafo a, --(SELECT id, version, user_id, tstamp, changeset_id, tags, nodes, bbox, linestring AS geom FROM osm_views.pinf_ways_auto)
      public.way_nodes b,
      public.nodes c 
    WHERE
      a.geom && c.geom AND
      a.id = b.way_id AND
      b.node_id = c.id
      AND (CASE WHEN sequence_id>0 AND (ST_Length(a.geom)*ST_LineLocatePoint(ST_GeometryN(a.geom,1), c.geom))=0 THEN 1 ELSE 0 END)=0 
  )a
  WHERE
    verifica=0
  GROUP BY
    id, node_id, dist, pos,geom_line, verifica
),

-- 2. PER GLI ARCHI CHE SI CHIUDONO
nodi_fine AS (
  SELECT 
    a.id, a.node_id, a.dist,
    CASE 
      WHEN b.id IS NULL THEN a.pos
      WHEN (b.id>0 AND a.pos=0) THEN 1
      ELSE 1
    END AS pos,
    a.rownum, a.geom_line
  FROM
    nodi a LEFT JOIN (SELECT id, MAX(rownum) AS rownum FROM nodi GROUP BY id)b ON a.id=b.id AND a.rownum=b.rownum
),

-- 3. CONTROLLA SE GLI ARCHI SI CHIUDONO (ROTONDE)
linea_chiusa AS (
  SELECT 
    a.id,
    CASE WHEN a.pos=b.pos THEN 0 ELSE 1 END AS linea_chiusa,
    a.rownum AS rownum_max
  FROM 
    (SELECT id, MAX(pos)pos, MAX(rownum) rownum FROM nodi GROUP BY id) a, 
    (SELECT id, MAX(pos)pos, MAX(rownum) rownum FROM nodi_fine GROUP BY id) b
  WHERE
    a.id=b.id AND a.rownum=b.rownum
),

-- 4. SE LA LINEA E' CHIUSA ALLORA BISOGNA AGGIUNGERE UN PUNTO: IL PUNTO CON 'POS=0' DIVENTA ANCHE IL PUNTO CON 'POS=1' 
nodi_all AS (
  -- nodi_fine
  SELECT id, node_id, dist, pos, rownum, geom_line
  FROM nodi

  UNION 
  
  -- linea chiusa: aggiungi un nodo. Il nodo con'pos=0' diventa anche il nodo con 'pos=1'
  SELECT
    a.id, a.node_id, a.dist, 1 AS pos, (rownum_max+1) AS rownum, geom_line --b.linea_chiusa
  FROM
    nodi_fine a,
    linea_chiusa b
  WHERE
    a.id=b.id AND linea_chiusa=1 AND pos=0
),
    

-- 3. SPEZZA GLI ARCHI
spezza_archi AS (
  SELECT 
    ROW_NUMBER() OVER(ORDER BY a.id) AS id, a.id AS way_originale, a.node_id AS node_start, b.node_id AS node_end, a.rownum as rownum1, b.rownum as rownum2,
    --a.pos, b.pos, 
    ST_LineSubstring(a.geom_line, a.pos, b.pos) AS geom   
  FROM 
    --nodi_fine a, nodi_fine b 
    nodi_all a, nodi_all b 
  WHERE 
    a.id=b.id AND
    a.rownum=(b.rownum-1)
),

-- 5. CONSIDERA SOLO ARCHI PERCORRIBILI DALLE AUTO E IMPOSTA CAMPO BUS(0,1) E ONEWAY(0,1), REVERSE(0,1)
bus_oneway AS ( 
  SELECT 
    id, version, user_id, tstamp, changeset_id, tags, nodes, bbox, geom,
    -- campo oneway (1:yes, 0:no)
    CASE
      WHEN w.tags -> 'oneway'='yes' THEN 1
      WHEN w.tags -> 'oneway'='-1' THEN 1
      WHEN w.tags -> 'junction'='roundabout' THEN 1
      WHEN w.tags -> 'highway'='motorway' THEN 1
      ELSE 0
    END AS oneway,
    -- campo percorrenza bus (1:yes, 0:no)
    CASE
      WHEN defined(w.tags,'bus') and w.tags -> 'bus' in ('no') THEN 0 --not in ('no')) THEN 0
      ELSE 1
    END AS bus,
    -- geom disegnata nel verso opposto (1:yes, 0:no)
    CASE WHEN (tags -> 'oneway'='-1') THEN 1 ELSE 0 END AS reverse
  FROM 
    grafo w -- osm_views.pinf_ways_auto w
  /*
  WHERE 
    -- filtra da manuale per selezionare le ways dove 
    NOT( 
     (NOT defined(w.tags,'highway'))
      OR (w.tags -> 'highway' = 'track' and w.tags -> 'tracktype' not in ('grade1'))
      OR (w.tags -> 'highway' not in ('motorway','motorway_link','trunk','trunk_link',
          'primary','primary_link','secondary','secondary_link','tertiary','tertiary_link',
          'unclassified','residential','living_street','service','road','track'))
      OR (w.tags -> 'highway' = 'ford')
      OR (coalesce(w.tags -> 'impassable','') = 'yes' or coalesce(w.tags -> 'status','') = 'impassable')
      OR (defined(w.tags,'motorcar') and w.tags -> 'motorcar' not in ('yes','permissive'))
      OR (defined(w.tags,'motor_vehicle') and w.tags -> 'motor_vehicle' not in ('yes','permissive'))
      OR (defined(w.tags,'vehicle') and w.tags -> 'vehicle' not in ('yes','permissive'))
      OR (defined(w.tags,'access') and w.tags -> 'access' not in ('yes','permissive'))
      OR (defined(w.tags,'railway') and w.tags -> 'railway' not in ('disused','abandoned','tram'))
    )
  */
)

-- 6. FINE: associa al nuovo grafo le informazione su ONEWAY, BUS, REVERSE
SELECT 
   a.id, a.way_originale, a.node_start, a.node_end, 
   b.version, b.tags, b.bus, b.oneway, b.reverse,
   a.geom
FROM
  spezza_archi a,
  bus_oneway b
WHERE
  a.way_originale=b.id;


-- 5. crea uno SPATIAL INDEX sulla tabella delle grafo per accelerare le query
CREATE INDEX web_00_grafo_idx ON adb.web_00_grafo USING GIST (geom);