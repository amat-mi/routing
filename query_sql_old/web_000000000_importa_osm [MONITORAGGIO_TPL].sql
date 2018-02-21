-- IMPORTAZIONE
 -- USARE SOLO COME TRACCIA

DELETE FROM adb.cart_osm_ways;
DELETE FROM adb.cart_osm_way_nodes;
DELETE FROM  adb.cart_osm_nodes;


COPY adb.cart_osm_ways
FROM E'/areascambio/osm/ways.csv'
with delimiter as ';' csv header


--INSERIRE QUI I MANCANTI
