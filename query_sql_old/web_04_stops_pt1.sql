-- TABELLA DI BASE PER IL ROUTING
-- associa il NODO PARTENZA/ARRIVO alle FERMATE PARTENZA/ARRIVO di ogni LINE_ID
-- N.B. viene effettuata una VERIFICA sui nodi che fanno parte delle LINES con una GEOM_CHECK=1 --> in alcuni casi il nome della fermata era
--      sbagliato e quindi corrispondeva un ID_NODO sbagliato, che non entrava all'interno del buffer (vedi query successiva)

-- TABELLE INPUT:
-- 1. adb.web_lines
-- 2. adb.web_03_fermate_nodo

-- TABELLA OUTPUT:
-- 1. adb.web_04_stops


-- 1. CREA SPATIAL INDEX
-- CREATE INDEX web_lines_idx ON adb.web_lines USING GIST (geom);

-- 2. seleziona i record sui quali bisogna fare la procedura delle STOPS 

CREATE TABLE adb.t_stops AS 
  SELECT 
    route_type, stop_id_s, stop_id_e, stop_code_s, stop_code_e, line_id, line_code, ST_TRANSFORM(geom,3003) as geom, geom_check
  FROM 
    adb.web_lines;

CREATE INDEX t_stops_idx
  ON adb.t_stops
  USING gist
  (geom);

CREATE TABLE adb.t_web_03_fermate_nodo as (
SELECT stop_id, stop_id_originali, id_nodo, ST_TRANSFORM(geom,3003) as geom, route_type
  FROM adb.web_03_fermate_nodo);
  
CREATE INDEX t_web_03_fermate_nodo_idx
  ON adb.t_web_03_fermate_nodo
  USING gist
  (geom);


-- 3. associa NODO_START e NODO_END
CREATE TABLE adb.t_stops_start AS (
  SELECT
    a.*, b.id_nodo::integer AS nodo_partenza
  FROM 
    adb.t_stops a,
    adb.t_web_03_fermate_nodo b
  WHERE 
    a.stop_id_s=ANY(stop_id_originali) AND a.route_type = b.route_type);

CREATE INDEX t_stops_start_idx
  ON adb.t_stops_start
  USING gist
  (geom);

  
-- 3.2.
CREATE TABLE adb.t_stops_end AS (
  SELECT 
    a.*, b.id_nodo::integer AS nodo_arrivo,
    ROW_NUMBER() OVER(ORDER BY line_id) contatore 
  FROM
    adb.t_stops_start a,
    adb.t_web_03_fermate_nodo b
  WHERE 
    a.stop_id_e=ANY(stop_id_originali) AND a.route_type = b.route_type);

CREATE INDEX t_stops_end_idx
  ON adb.t_stops_end
  USING gist
  (geom);
-----------------------------------------------------------------------------------------------------------------
-- 4. VERIFICA (se un ID_NODO di una fermata (STOP_ID_S/E) non appartiene al buffer, vuol dire che c'e' un errore: 
--    scritto male il codice fermata?
--    senza questa verifica il ROUTING CRASHA

-- 4.1. seleziona i record sui quali bisogna fare la procedura delle LINES 
CREATE TABLE adb.t_lines AS (
  SELECT 
    route_type, stop_id_s, stop_id_e, stop_code_s, stop_code_e, line_id, line_code, 
    geom_check, nodo_partenza, nodo_arrivo, contatore, ST_TRANSFORM(geom, 3003) AS geom 
  FROM 
    adb.t_stops_end
  WHERE
    geom_check=1);

CREATE INDEX t_lines_idx
  ON adb.t_lines
  USING gist
  (geom);

-- 4.2. CREATE A BUFFER AROUND THE LINES
CREATE TABLE adb.t_lines_buffer AS(
  SELECT 
    route_type, stop_id_s, stop_id_e, stop_code_s, stop_code_e, line_id, line_code, contatore, ST_BUFFER(geom,200) AS geom, geom_check
  FROM 
    adb.t_lines
);
CREATE INDEX t_lines_buffer_idx
  ON adb.t_lines_buffer
  USING gist
  (geom);

-- 4.3. VERIFICA
CREATE TABLE adb.t_verifica AS (
  SELECT a
     route_type, stop_id_s, stop_id_e, contatore, SUM(prob_start) prob_start, SUM(prob_end) prob_end 
  FROM
    (SELECT a.route_type, stop_id_s, stop_id_e, contatore, 1 prob_start, 0 prob_end 
     FROM 
       adb.t_lines_buffer a,
       adb.t_web_03_fermate_nodo b
     WHERE
       NOT ST_INTERSECTS(a.geom, b.geom) AND
       stop_id_s=ANY(stop_id_originali) 
       AND a.route_type = b.route_type
       
    UNION

     SELECT a.route_type, stop_id_s, stop_id_e, contatore, 0 prob_start, 1 prob_end
     FROM 
       adb.t_lines_buffer a,
       adb.t_web_03_fermate_nodo b
     WHERE
       NOT ST_INTERSECTS(a.geom, b.geom) AND
       stop_id_e=ANY(stop_id_originali)
       AND a.route_type = b.route_type
    )a
  GROUP BY
    route_type, stop_id_s, stop_id_e, contatore
  ORDER BY contatore
);




DROP TABLE adb.web_04_stops;
CREATE TABLE adb.web_04_stops AS 
-- 5. SELEZIONA I RECORD CHE NON HANNO PROBLEMI
SELECT 
  a.*, 
  CASE WHEN b.contatore IS NULL THEN 1 ELSE 0 END AS corretto
FROM
  adb.t_stops_end a LEFT JOIN adb.t_verifica b ON a.contatore=b.contatore;
  
-- 6. CREA SPATIAL INDEX
CREATE INDEX web_04_stops_idx ON adb.web_04_stops USING GIST (geom);

--7. TEMP: metti corretto = 1 sempre
--UPDATE adb.web_04_stops SET corretto = 1 

DROP TABLE adb.t_stops;
DROP TABLE adb.t_web_03_fermate_nodo;
DROP TABLE adb.t_stops_start ;
DROP TABLE adb.t_stops_end ;
DROP TABLE adb.t_lines ;
DROP TABLE adb.t_lines_buffer ;
DROP TABLE adb.t_verifica ;
