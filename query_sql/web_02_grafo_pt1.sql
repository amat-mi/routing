-- CREAZIONE GRAFO utile per ROUTING (e nuova topologia con nodi).
-- alle ways originali (che vengono tenute) si aggiungono delle ways nuove, create spezzando il grafo dove ci sono le fermate. 
-- Sono stati creati i campi WAY_MODIFICATO(0,1), 
-- che indica se il record e' originale oppure ottenuto spezzando il grafo, 
-- e USARE(0,1), che indica se la way e' utile per il routing.
-- se il campo e' REVERSE allora e' stato invertito il senso della geometria
-- N.B. Il ROUTING va fatto SOLO su quei record che hanno il campo USARE=1
-- 
-- N.B. Ho dovuto ricreare la topologia di nuovo, per creare i nuovi nodi dove si sono spezzati gli archi.


-- TABELLE INPUT:
-- 1. adb.web_01_fermate
-- 2. adb.web_00_grafo
-- 3. adb.web_00_grafo_vertices_pgr

-- TABELLA OUTPUT:
-- 1. adb.web_02_grafo 


CREATE TABLE adb.web_02_grafo AS

-- 1. Se non è statato fatto, crea uno SPATIAL INDEX sulla tabella delle grafo per accelerare le query
/*CREATE INDEX web_00_grafo_idx ON adb.web_00_grafo USING gist (geom);*/  -- teoria: CREATE INDEX [indexname] ON [tablename] USING GIST ( [geometrycolumn] );

-- 2. trova l'ARCO sul quale la fermata verra' proiettata
WITH fermate_arco AS(
  SELECT DISTINCT ON(a.stop_id) a.stop_id,
    b.id, b.way_originale, b.source, b.target, b.oneway, b.bus, b.reverse, b.tags,
    a.geom AS geom_point, b.geom AS geom_line
  FROM
    --adb.web_00_grafo AS b
    (SELECT 
       id, way_originale, node_start, node_end, version, tags,  bus, oneway, reverse, source, target,
       -- REVERSE
       CASE WHEN reverse=1 THEN ST_REVERSE(geom) ELSE geom END AS geom
    FROM 
      adb.web_00_grafo) b
  INNER JOIN
    adb.web_01_fermate_buffer a
  ON
    a.geom_buff && b.geom,  
    ST_DWithin(a.geom, b.geom, 240) 
  ORDER BY a.stop_id, ST_Distance(b.geom, a.geom)
),

-- 3. proietta la fermata sull'arco identificato al punto 3.
--    crea il campo LOCATE che servira' per spezzare le linee nel punto corretto
fermate_proiettate AS (
  SELECT 
    stop_id, 
    id, way_originale, source, target, oneway, bus, reverse,
    ST_LineLocatePoint(geom_line, geom_point) locate, 
    geom_line
  FROM 
    fermate_arco a
),

-- 5. ordina le fermate proiettate sull'arco al punto precedente 4.
--    crea il campo CONTA che serve per capire quante fermate vengono proiettate su un arco. 
--    N.B. non vengono considerate le fermate nella posizione 0 e 1 perche' coincidono gia' con la posizione uguale al nodo 
fermate_ordinate AS (
  SELECT
    stop_id, id, way_originale, source, target, 
    ------
    CASE 
      WHEN locate=0 THEN 0.01  
      WHEN locate=1 THEN 0.99
      ELSE locate
    END AS locate, 
    ------
    oneway, bus, reverse,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY locate) conta,
    -- crea il NUOVO NODO
    (ROW_NUMBER() OVER (ORDER BY id, locate)+id_nodo_max) nodo_new,
    geom_line AS geom
  FROM 
    fermate_proiettate,
    (SELECT MAX(id) id_nodo_max FROM adb.web_00_grafo_vertices_pgr)b
  WHERE (locate<>0 OR locate<>1)
),

-- 6. spezza gli archi dove ci sono le fermate
archi_spezzati AS(
  SELECT *, ROW_NUMBER() OVER (ORDER BY id, conta) AS contatore
  FROM
   (
    -- da posizione 0
    SELECT 
      a.id, a.way_originale, a.source, a.nodo_new AS target, a.oneway, a.bus, 0 AS conta, ST_LineSubstring(a.geom, 0, a.locate) as geom
    FROM 
      fermate_ordinate a,
      (SELECT id, MIN(conta) AS conta FROM fermate_ordinate GROUP BY id) b
    WHERE
      a.id=b.id AND
      a.conta=b.conta

    UNION

    -- fino a posizione 1
    SELECT 
      a.id, a.way_originale, a.nodo_new AS source, a.target, a.oneway, a.bus, b.conta, ST_LineSubstring(a.geom, a.locate, 1) as geom 
    FROM 
      fermate_ordinate a,
      (SELECT id, MAX(conta) AS conta FROM fermate_ordinate GROUP BY id) b
    WHERE
      a.id=b.id AND
      a.conta=b.conta

    UNION

    -- nelle altre posizioni che non sono la 0 e 1
    SELECT 
      a.id, a.way_originale, a.nodo_new AS source, b.nodo_new AS target, a.oneway, a.bus, a.conta, ST_LineSubstring(a.geom, a.locate, b.locate) as geom 
    FROM 
      fermate_ordinate a,
      fermate_ordinate b
    WHERE 
      a.id=b.id AND
      a.conta=(b.conta-1) 
    )a
  ORDER BY id, conta
),

-- 7. Unisci archi originali con i nuovi archi spezzati:
--    Archi Nuovi Spezzati + Archi Originali
nuovo_grafo AS (
  -- archi modificati.
  -- N.B. 1 nel campo "WAY_MODIFICATO" perche e' stata modificata
  SELECT
    (a.contatore+b.id_max) AS id_new, 
    id AS id_originale,  a.way_originale, a.source, a.target, a.oneway, a.bus,
    CASE WHEN a.bus=1 THEN ST_LENGTH(a.geom) ELSE (ST_LENGTH(a.geom)+10000) END AS cost,
    CASE 
      WHEN a.bus=0 THEN (ST_LENGTH(a.geom)+10000)
      WHEN a.oneway=1 THEN (ST_LENGTH(a.geom)+10000) 
      ELSE ST_LENGTH(a.geom) 
    END AS rcost, 
    1 AS way_modificato, 
    a.geom 
  FROM
    archi_spezzati a,
    (SELECT MAX(id) AS id_max FROM adb.web_00_grafo) b
  
  UNION
  -- archi non modificati
  -- N.B. 0 nel campo "WAY_MODIFICATO" perche non e' stata modificata
  SELECT 
    a.id AS id_new, a.id AS id_originale, a.way_originale, a.source, a.target, a.oneway, a.bus, 
    CASE WHEN a.bus=1 THEN ST_LENGTH(a.geom) ELSE (ST_LENGTH(a.geom)+10000) END AS cost,
    CASE 
      WHEN a.bus=0 THEN (ST_LENGTH(a.geom)+10000)
      WHEN a.oneway=1 THEN (ST_LENGTH(a.geom)+10000) 
      ELSE ST_LENGTH(a.geom) 
    END AS rcost, 
    0 AS way_modificato, 
    a.geom 
  FROM 
    adb.web_00_grafo a --LEFT JOIN archi_spezzati b ON a.id=b.id
)

-- 8. Crea il nuovo grafo e compila il campo "USARE" (0,1) che indica se si deve usare la way per il routing
--    Se la way e' stata modificata il campo "USARE"=0 --> prendere la nuova way
  SELECT
    b.id_new, b.id_originale, b.way_originale, b.source::integer AS source_old, b.target::integer AS target_old, b.oneway, b.bus, b.cost::numeric, b.rcost::numeric, b.way_modificato,
    CASE 
      WHEN max_id>0 AND way_modificato=1 THEN 1
      WHEN max_id=0 THEN 1 
      ELSE 0 END usare,
    b.geom
  FROM 
    (SELECT id_originale, MAX(way_modificato) max_id FROM nuovo_grafo GROUP BY id_originale)a,
    nuovo_grafo b
  WHERE
    a.id_originale=b.id_originale;

-- 9. CREA SPATIAL INDEX
CREATE INDEX web_02_grafo_idx ON adb.web_02_grafo USING GIST (geom);


