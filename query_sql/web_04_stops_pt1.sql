-- TABELLA DI BASE PER IL ROUTING
-- associa il NODO PARTENZA/ARRIVO alle FERMATE PARTENZA/ARRIVO di ogni LINE_ID
-- N.B. viene effettuata una VERIFICA sui nodi che fanno parte delle LINES con una GEOM_CHECK=1 --> in alcuni casi il nome della fermata era
--      sbagliato e quindi corrispondeva un ID_NODO sbagliato, che non entrava all'interno del buffer (vedi query successiva)

-- TABELLE INPUT:
-- 1. adb.web_lines
-- 2. adb.web_03_fermate_nodo

-- TABELLA OUTPUT:
-- 1. adb.web_04_stops


CREATE TABLE adb.web_04_stops AS 
-- 1. CREA SPATIAL INDEX
-- CREATE INDEX web_lines_idx ON adb.web_lines USING GIST (geom);

-- 2. seleziona i record sui quali bisogna fare la procedura delle STOPS 
WITH stops AS (
  SELECT 
    stop_id_s, stop_id_e, stop_code_s, stop_code_e, line_id, line_code, geom, geom_check
  FROM 
    adb.web_lines
),

-- 3. associa NODO_START e NODO_END
stops_start AS (
  SELECT
    a.*, b.id_nodo::integer AS nodo_partenza
  FROM 
    stops a,
    adb.web_03_fermate_nodo b
  WHERE 
    a.stop_id_s=ANY(stop_id_originali)
),

-- 3.2.
stops_end AS (
  SELECT 
    a.*, b.id_nodo::integer AS nodo_arrivo,
    ROW_NUMBER() OVER(ORDER BY line_id) contatore 
  FROM
    stops_start a,
    adb.web_03_fermate_nodo b
  WHERE 
    a.stop_id_e=ANY(stop_id_originali)
),

-----------------------------------------------------------------------------------------------------------------
-- 4. VERIFICA (se un ID_NODO di una fermata (STOP_ID_S/E) non appartiene al buffer, vuol dire che c'e' un errore: 
--    scritto male il codice fermata?
--    senza questa verifica il ROUTING CRASHA

-- 4.1. seleziona i record sui quali bisogna fare la procedura delle LINES 
lines AS (
  SELECT 
    stop_id_s, stop_id_e, stop_code_s, stop_code_e, line_id, line_code, 
    geom_check, nodo_partenza, nodo_arrivo, contatore, ST_TRANSFORM(geom, 3003) AS geom 
  FROM 
    stops_end
  WHERE
    geom_check=1
),

-- 4.2. CREATE A BUFFER AROUND THE LINES
lines_buffer AS(
  SELECT 
    stop_id_s, stop_id_e, stop_code_s, stop_code_e, line_id, line_code, contatore, ST_BUFFER(geom,200) AS geom, geom_check
  FROM 
    lines
),

-- 4.3. VERIFICA
verifica AS (
  SELECT 
    stop_id_s, stop_id_e, contatore, SUM(prob_start) prob_start, SUM(prob_end) prob_end 
  FROM
    (SELECT stop_id_s, stop_id_e, contatore, 1 prob_start, 0 prob_end 
     FROM 
       lines_buffer a,
       adb.web_03_fermate_nodo b
     WHERE
       NOT ST_INTERSECTS(a.geom, b.geom) AND
       stop_id_s=ANY(stop_id_originali)
       
    UNION

     SELECT stop_id_s, stop_id_e, contatore, 0 prob_start, 1 prob_end
     FROM 
       lines_buffer a,
       adb.web_03_fermate_nodo b
     WHERE
       NOT ST_INTERSECTS(a.geom, b.geom) AND
       stop_id_e=ANY(stop_id_originali)
    )a
  GROUP BY
    stop_id_s, stop_id_e, contatore
  ORDER BY contatore
)

-- 5. SELEZIONA I RECORD CHE NON HANNO PROBLEMI
SELECT 
  a.*, 
  CASE WHEN b.contatore IS NULL THEN 1 ELSE 0 END AS corretto
FROM
  stops_end a LEFT JOIN verifica b ON a.contatore=b.contatore;
  
-- 6. CREA SPATIAL INDEX
CREATE INDEX web_04_stops_idx ON adb.web_04_stops USING GIST (geom);


