SELECT t_id AS t_id, -1::int8 AS t_basket, 'dm01vch24lv95deinzelobjekte_objektnummer'::varchar(60) AS t_type, NULL::varchar(200) AS t_ili_tid,
  nummer, gwr_egid, objektnummer_von
FROM agi_dm01avso24.einzelobjekte_objektnummer;
