-- non eseguirlo come un unico script, ma i vari sub-script separatamente


-- ESPORTAZIONE I TRE SELECT SEPARATAMENTE COME TESTO : 


--GRAFO
SELECT id, tags, nodes, bbox, linestring
  FROM public.ways
  WHERE (tags::text LIKE '%highway%' or tags::text LIKE '%railway%' )
AND  LINESTRING is not null
  AND  st_isvalid(LINESTRING);

--WAY_NODES
WITH ID_VALIDI AS (
	SELECT *
	  FROM public.ways
	  WHERE (tags::text LIKE '%highway%' or tags::text LIKE '%railway%' )
	AND  LINESTRING is not null
	  AND  st_isvalid(LINESTRING))

SELECT * FROM public.way_nodes 
	JOIN ID_VALIDI USING (way_id);

--NODES

WITH NODI_VALIDI AS (
	SELECT DISTINCT unnest(nodes) AS id
	  FROM public.ways
	  WHERE (tags::text LIKE '%highway%' or tags::text LIKE '%railway%' )
	AND  LINESTRING is not null
	  AND  st_isvalid(LINESTRING))

SELECT * FROM public.nodes 
	JOIN NODI_VALIDI USING (id);







