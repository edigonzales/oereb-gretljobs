 INSERT INTO
  ${dbSchema}.t_ili2db_basket (t_id, dataset, topic, t_ili_tid, attachmentkey, domains)
VALUES
  (-2, null, 'PLZO-Daten importiert per Db2Db-Step', null, '-', null)
ON CONFLICT DO NOTHING
;
