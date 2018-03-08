--- LE SEGUENTI QUERY LAVORANO SU DB osmosis



-- non eseguirlo come un unico script, ma i vari sub-script separatamente


-- ESPORTARE I TRE SELECT SEPARATAMENTE COME TESTO : 


--GRAFO
---- seleziona tutti gli archi con geometria valida e non nulla

SELECT id, tags, nodes, bbox, linestring
  FROM public.ways
---- aggiungere archi pedonali per PTAL
WHERE (tags::text LIKE '%highway%' or tags::text LIKE '%railway%' )
--------------------
AND  LINESTRING is not null
  AND  st_isvalid(LINESTRING);



--WAY_NODES
----  topologia dell' arco espressa come sequenza di nodi

WITH ID_VALIDI AS (
	SELECT *
	  FROM public.ways
	---- aggiungere archi pedonali per PTAL
	  WHERE (tags::text LIKE '%highway%' or tags::text LIKE '%railway%' )
	-------
	AND  LINESTRING is not null
	  AND  st_isvalid(LINESTRING))

SELECT * FROM public.way_nodes 
	JOIN ID_VALIDI USING (way_id);

--NODES
--- nodi con geometria
WITH NODI_VALIDI AS (
	SELECT DISTINCT unnest(nodes) AS id
	  FROM public.ways
	---- aggiungere archi pedonali per PTAL
	  WHERE (tags::text LIKE '%highway%' or tags::text LIKE '%railway%' )
	AND  LINESTRING is not null
	  AND  st_isvalid(LINESTRING))

SELECT * FROM public.nodes 
	JOIN NODI_VALIDI USING (id);







