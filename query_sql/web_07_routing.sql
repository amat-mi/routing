-- ASSOCIA LA GEOM ALLA TABELLA DEL ROUTING per creare i percorsi

-- TABELLE INPUT:
-- 1. adb.web_06_routing
-- 2. adb.web_02_grafo

-- TABELLA OUTPUT:
-- 1. adb.web_08_routing_fine

-- 1. metti in ordine per creare la way START_NODE-END_NODE
CREATE TABLE adb.web_07_routing AS
SELECT 
  a.nodo_partenza, a.nodo_arrivo, a.stop_partenza, a.stop_arrivo, 
  a.seq, a.id1 AS id_start, b.id1 AS id_end, a.line_id, a.geom_check, a.contatore
FROM
  adb.web_06_routing a,
  adb.web_06_routing b
WHERE
  a.seq=(b.seq-1) AND
  a.contatore=b.contatore;


-- 2. CREA INDEX per velocizzare la procedura
CREATE UNIQUE INDEX web_07_routing_idx ON adb.web_07_routing (contatore, id_start, id_end);
CREATE UNIQUE INDEX web_02_grafo_idx1 ON adb.web_02_grafo (source, target, id_new);

-- 3. associa le geom
CREATE TABLE adb.web_08_routing_fine AS
SELECT 
  --a.*, 
  a.seq, a.id_start, a.id_end, a.line_id, a.contatore,
  b.id_new, b.geom
FROM
  adb.web_07_routing a,
  adb.web_02_grafo b
WHERE 
  --a.contatore=b.contatore AND 
  (a.id_start=b.source AND a.id_end=b.target) OR (a.id_end=b.source AND a.id_start=b.target) 
GROUP BY 
    a.seq, a.id_start, a.id_end, a.line_id, a.contatore, b.id_new, b.geom
ORDER BY 
  a.seq