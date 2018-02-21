-- PRIMA SELEZIONE DEL DATO OSM, CON APPLICAZIONE DEI VARIATORI AL COSTO
-- creo un unico grafo di riferimento per i diversi modi: BUS, TRAM, METRO, TRENO


-- TABELLE INPUT:
-- 1. adb.cart_osm_ways

-- TABELLA OUTPUT:
-- 1. adb.web_000_grafo_costi

DROP TABLE adb.web_000_grafo_costi;
CREATE TABLE adb.web_000_grafo_costi AS 

--USO WITH PER POTER FARE IL CAST DEL CAMPO TAGS
WITH ways as(
	select
    w.id,
    w.version,
    w.user_id,
    w.tstamp,
    w.changeset_id,
    w.tags::hstore,
    w.nodes,
    w.bbox,
    w.linestring,  
    CASE 
      WHEN ((w.tags -> 'highway'::text) = 'motorway '::text or (w.tags -> 'bus'::text) ='yes' or ((w.tags -> 'psv'::text) <> ''::text ) ) THEN 0.9 
      WHEN ((w.tags -> 'highway'::text) = 'trunk'::text ) THEN  0.92
      WHEN ((w.tags -> 'highway'::text) = 'primary'::text ) THEN  0.95
      WHEN ((w.tags -> 'highway'::text) = 'secondary'::text ) THEN  0.97
      WHEN ((w.tags -> 'highway'::text) = 'unclassified'::text ) THEN  1.05
      WHEN ((w.tags -> 'highway'::text)= ANY (ARRAY ['residential'::text,'service'::text, 'living_street'::text]) AND NOT (w.tags -> 'psv'::text) <> ''::text ) THEN  1.1
    ELSE 1
    END AS varcosto
   FROM  adb.cart_osm_ways w )

 --ESTRAGGO I GRAFI DI RIFERIMENTO
 (
 SELECT 
    3 as route_type, -- 'BUS'::text as modo,
    w.id,
    w.version,
    w.user_id,
    w.tstamp,
    w.changeset_id,
    w.tags::hstore,
    w.nodes,
    w.bbox, 
    w.linestring,
    w.varcosto
    
   FROM ways w
  WHERE
	--ARCHI TPL-SPECIFICI
	--trattandosi molto spesso di errori, uso codifiche molto specifiche
	--1) archi con Highway = SERVICE riservati a TPL (preferenziali, parcheggi metro etc)
	((w.tags -> 'highway'::text) = 'service'::text 
	AND NOT COALESCE(w.tags -> 'access'::text, ''::text) = ANY (ARRAY['private'::text, 'agricultural'::text, 'forestry'::text, 'restricted'::text, 'delivery'::text]) 
	AND NOT COALESCE(w.tags -> 'motor_vehicle'::text, ''::text) = ANY (ARRAY['no'::text]) 
	--AND NOT (w.tags -> 'motor_vehicle'::text) = 'no'::text
	
		   --<-- integrazione TPL
	
	--2) archi con altro highway con vincoli sull'accesso 
	OR (w.tags -> 'access'::text) = ANY (ARRAY['permissive'::text, 'no'::text]) AND ((w.tags -> 'highway'::text) = ANY (ARRAY['motorway'::text, 'motorway_link'::text, 'trunk'::text, 'trunk_link'::text, 
                                                                  'primary'::text, 'primary_link'::text, 'secondary'::text, 'secondary_link'::text, 'tertiary'::text, 
                                                                  'tertiary_link'::text,  'unclassified'::text, 'residential'::text, 'living_street'::text,  
                                                                  'road'::text]))  
	
	
	--3) archi specifici con flag motorway = no, ma in cui è consentito il transito [tolto: caricheremmo molti archi che è corretto escludere]
	--OR (w.tags -> 'motor_vehicle'::text) = 'no'::text  AND ((w.tags -> 'highway'::text) = ANY (ARRAY['motorway'::text, 'motorway_link'::text, 'trunk'::text, 'trunk_link'::text, 
        --                                                          'primary'::text, 'primary_link'::text, 'secondary'::text, 'secondary_link'::text, 'tertiary'::text, 
        --                                                         'tertiary_link'::text,  'residential'::text, 'living_street'::text,  
        --                                                         'road'::text]))  --<-- integrazione TPL	
	--4) archi specifici da includere (includo quelli precedentemente desunti da grafo pedonale
        OR w.id in(500790772,72889775,437268493,417065628,337622947,184207162,278242130,23449144,158183080,332413475,27854539,316197534,316197537,331312071,48121606)) 

        --5) archi specifici da escludere
        AND      w.id not in(51481380,56327670)
        
        
        
	--PARTE RIPRESA DAL GRAFO STRADALE PRIVATO
	 OR NOT (NOT defined(w.tags, 'highway'::text) OR 
            (w.tags -> 'highway'::text) = 'track'::text AND 
            COALESCE(w.tags -> 'tracktype'::text, ''::text) <> 'grade1'::text 
			  OR ((w.tags -> 'highway'::text) <> ALL (ARRAY['motorway'::text, 'motorway_link'::text, 'trunk'::text, 'trunk_link'::text, 
                                                                  'primary'::text, 'primary_link'::text, 'secondary'::text, 'secondary_link'::text, 'tertiary'::text, 
                                                                  'tertiary_link'::text, 'unclassified'::text, 'residential'::text, 'living_street'::text, 'service'::text, 
                                                                  'road'::text, 'track'::text])) 
			  OR (w.tags -> 'highway'::text) = 'ford'::text 
			  OR COALESCE(w.tags -> 'impassable'::text, ''::text) = 'yes'::text 
			  OR COALESCE(w.tags -> 'status'::text, ''::text) = 'yes'::text 
			  OR defined(w.tags, 'ford'::text) AND (COALESCE(w.tags -> 'motorcar'::text, ''::text) <> ALL (ARRAY['yes'::text, 'permissive'::text])) 
			  OR defined(w.tags, 'ford'::text) AND (COALESCE(w.tags -> 'motor_vehicle'::text, ''::text) <> ALL (ARRAY['yes'::text, 'permissive'::text])) 
			  OR defined(w.tags, 'ford'::text) AND (COALESCE(w.tags -> 'vehicle'::text, ''::text) <> ALL (ARRAY['yes'::text, 'permissive'::text])) 
			  OR defined(w.tags, 'ford'::text) AND (COALESCE(w.tags -> 'access'::text, ''::text) <> ALL (ARRAY['yes'::text, 'permissive'::text])) 
			  OR (COALESCE(w.tags -> 'motorcar'::text, ''::text) = ANY (ARRAY['private'::text, 'agricultural'::text, 'forestry'::text, 'no'::text, 'restricted'::text, 'delivery'::text])) 
			  OR (COALESCE(w.tags -> 'motor_vehicle'::text, ''::text) = ANY (ARRAY['private'::text, 'agricultural'::text, 'forestry'::text, 'no'::text, 'restricted'::text, 'delivery'::text])) 
			  OR (COALESCE(w.tags -> 'vehicle'::text, ''::text) = ANY (ARRAY['private'::text, 'agricultural'::text, 'forestry'::text, 'no'::text, 'restricted'::text, 'delivery'::text])) 
			  OR (COALESCE(w.tags -> 'access'::text, ''::text) = ANY (ARRAY['private'::text, 'agricultural'::text, 'forestry'::text, 'no'::text, 'restricted'::text, 'delivery'::text])) 
			  OR defined(w.tags, 'railway'::text) 
                    AND ((w.tags -> 'railway'::text) <> ALL (ARRAY['tram'::text, 'abandoned'::text, 'disused'::text])))

UNION

SELECT 
    0 as route_type, --'TRAM' as modo,
    w.id,
    w.version,
    w.user_id,
    w.tstamp,
    w.changeset_id,
    w.tags,
    w.nodes,
    w.bbox, 
    w.linestring,
    w.varcosto
   FROM ways w
  WHERE
	(w.tags -> 'railway'::text) = 'tram'::text 
UNION
SELECT 
    1 as route_type, --'METRO' as modo,
    w.id,
    w.version,
    w.user_id,
    w.tstamp,
    w.changeset_id,
    w.tags,
    w.nodes,
    w.bbox, 
    w.linestring,
    w.varcosto
   FROM ways w
  WHERE
	(w.tags -> 'railway'::text) = 'subway'::text 
UNION
SELECT 
    2 as route_type, --'FERROVIA' as modo,
    w.id,
    w.version,
    w.user_id,
    w.tstamp,
    w.changeset_id,
    w.tags,
    w.nodes,
    w.bbox, 
    w.linestring,
    w.varcosto
   FROM ways w
  WHERE
	(w.tags -> 'railway'::text) = 'rail'::text );


CREATE INDEX web_000_grafo_costi_idx ON adb.web_000_grafo_costi USING GIST (linestring);


GRANT ALL ON TABLE adb.web_000_grafo TO adb_ls;
GRANT ALL ON TABLE adb.web_000_grafo TO sis_lp;
GRANT SELECT ON TABLE adb.web_000_grafo TO public
