WITH datasets AS 
(
    INSERT INTO
        arp_npl_oereb.t_ili2db_dataset (t_id, datasetname) 
    VALUES 
        (nextval('arp_npl_oereb.t_ili2db_seq'::regclass),'2491'),
        (nextval('arp_npl_oereb.t_ili2db_seq'::regclass),'2498')
    RETURNING *
)
INSERT INTO 
    arp_npl_oereb.t_ili2db_basket (t_id, dataset, topic, attachmentkey)
SELECT
    nextval('arp_npl_oereb.t_ili2db_seq'::regclass) AS t_id,
    datasets.t_id AS dataset,
    'OeREBKRMtrsfr_V1_1.Transferstruktur' AS topic,
    'ch.so.arp.nutzungsplanung.oereb.'||datasets.datasetname AS attachmentkey
FROM
    datasets 
;
