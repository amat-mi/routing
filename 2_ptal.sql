-- CALCOLA IL PTAL
--- https://files.datapress.com/london/dataset/public-transport-accessibility-levels/PTAL-methodology.pdf



CREATE TABLE ptal._2017_a06_ptal_giornaliero AS 
-- FERMATE BUS ENTRO 640m, TRENO E MM ENTRO 960m
WITH length AS(
  SELECT 
    *, 
    CASE 
      WHEN tipo='sup' AND distance<=640 THEN 1
      WHEN (tipo='treno' OR tipo='mm') AND distance<=960 THEN 1
      ELSE 0
    END AS length_verifica  
  FROM ptal._2017_a05_stops_dist_fermate
),

-- CALCOLA SWT, ACCESS, EDF
edf AS(
  SELECT
    a.nodo, a.tipo, a.fermata, a.distance, 
    b.n_corse, 
    a.distance/80 AS walk_time,
    CASE WHEN a.tipo='sup' THEN (2+ 0.5*(60/CAST(b.n_corse AS float))) ELSE (0.75+ 0.5*(60/CAST(b.n_corse AS float))) END AS swt, 
    (a.distance/80)+(CASE WHEN a.tipo='sup' THEN (2+ 0.5*(60/CAST(b.n_corse AS float))) ELSE (0.75+ 0.5*(60/CAST(b.n_corse AS float))) END) AS accesso,
    (30/((a.distance/80)+(CASE WHEN a.tipo='sup' THEN (2+ 0.5*(60/CAST(b.n_corse AS float))) ELSE (0.75+ 0.5*(60/CAST(b.n_corse AS float))) END))) AS edf,
    a.the_geom AS geom 
  FROM
    (SELECT * FROM length WHERE length_verifica=1) AS a,
    (SELECT stop_id, modo, ROUND((SUM(n_corse)/26),2) n_corse FROM ptal._2017_stop_transit GROUP BY stop_id, modo) AS b
  WHERE
    a.fermata=b.stop_id

    --and nodo=859442 --and fascia_inizio_corsa=8
  ORDER BY a.nodo
),

-- ORDINA IN BASE AL MODO E VICINANZA
weight AS(
  SELECT
    *, ROW_NUMBER() OVER(PARTITION BY b.nodo, b.tipo ORDER BY b.edf DESC ) AS weight
  FROM
    edf b
  ORDER BY b.nodo, b.tipo
),

-- CALCOLA ACC_INDEX
ptal AS (
  SELECT 
    nodo, tipo, fermata, distance, n_corse, walk_time, swt, accesso, edf, 
    CASE WHEN weight=1 THEN 1 ELSE 0.5 END AS weight,
    edf*(CASE WHEN weight=1 THEN 1 ELSE 0.5 END) AS acc_index, geom
  FROM
    weight
)

-- FINE
SELECT
  nodo, SUM(a.acc_index) AS acc_index, geom
FROM
  ptal a
GROUP BY
  nodo, geom

--select * from weight
