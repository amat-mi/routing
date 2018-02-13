--10. DIST MIN FERMATA-NODO PER TIPO

CREATE TABLE ptal._2017_a05_stops_dist_fermate AS

WITH fermate_dist AS (
  SELECT a.fermata, b.modo AS tipo, a.nodo, a.distance 
  
  -------- tabella risultante dal routing
  FROM  ptal._2017_a04_stops_dist_ft a,
  -------------------------------
  
    (SELECT stop_id, modo FROM ptal._2017_stop_transit GROUP BY stop_id, modo) b
  WHERE  a.fermata=b.stop_id
    --and fermata='10001'
  GROUP BY a.fermata, b.modo, a.nodo, a.distance
),

sup AS(
  SELECT nodo, fermata, tipo, min(distance) AS distance
  FROM fermate_dist 
  WHERE tipo='sup'
  GROUP BY nodo, fermata, tipo
),

treno AS(
  SELECT nodo, fermata, tipo, min(distance) AS distance
  FROM fermate_dist 
  WHERE tipo='treno'
  GROUP BY nodo, fermata, tipo
),

mm AS(
  SELECT nodo, fermata, tipo, min(distance) AS distance
  FROM fermate_dist 
  WHERE tipo='mm'
  GROUP BY nodo, fermata, tipo
)

SELECT b.*, a.the_geom 
FROM 
  ptal._2017_segments_foot_vertices_pgr a,
  (SELECT * FROM sup UNION SELECT * FROM treno UNION SELECT * FROM mm)b
WHERE a.id=b.nodo
ORDER BY nodo
