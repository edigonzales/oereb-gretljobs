/*
 * Die korrekte Reihenfolge der Queries ist zwingend. 
 * 
 * Es wird versucht möglichst rasch die Daten in den Tabellen zu speichern. So
 * können die Queries gekapselt werden und/oder in nachvollziehbareren 
 * Teilschritten durchgeführt werden. Alternativ kann man (fast) alles in einer sehr
 * langen CTE umbauen.
 * 
 * Es wird versucht wenn immer möglich die Original-TID (resp. der PK aus der 
 * Quelltabelle) in der Zieltabelle beizubehalten. Damit bleiben Beziehungen
 * 'bestehen' und sind einfacher zu behandeln.
 */

/*
 * Die Eigentumsbeschränkungen können als erstes persistiert werden. Der Umbau der anderen Objekte erfolgt anschliessend.
 * Verschiedene Herausforderungen / Spezialitäten müssen behandelt werden:
 * 
 * (1) basket und dataset müssen eruiert und als FK gespeichert werden. Beide werden
 * werden in einer Subquery ermittelt. Dies ist möglich, da bereits die zuständigen Stellen
 * vorhanden sein müssen, weil sie mitexportiert werden und daher den gleichen Dataset-Identifier
 * aufweisen (im Gegensatz dazu die Gesetze).
 * 
 * (2) Die Grundnutzung wird nicht flächendeckend in den ÖREB-Kataster überführt, d.h. es
 * gibt Grundnutzungen, die nicht Bestandteil des Katasters sind. Dieser Filter ist eine
 * einfache WHERE-Clause.
 * 
 * (3) Die Attribute 'publiziertab' und 'rechtsstatus' sind im kantonalen Modell nicht in
 * der Typ-Klasse vorhanden und werden aus diesem Grund für den ÖREB-Kataster
 * ebenfalls von der Geometrie-Klasse verwendet. Der Join führt dazu, dass ein unschönes 
 * Distinct notwendig wird. Und dass für den Typ / für die Eigentumsbeschränkung ein 
 * willkürliches Datum gewählt wird (falls es unterschiedliche Daten gibt).
 * 
 * (4) Momentan geht man von der Annahme aus, dass bei den diesen Eigentumsbeschränkungen
 * die Gemeinde die zuständige Stelle ist. Falls das nicht mehr zutrifft, muss man die
 * zuständigen Stellen eventuell in einem nachgelagerten Schritt abhandeln.
 * 
 * (5) Unschönheit: Exportiert werden alle zuständigen Stellen, die vorgängig importiert wurden. 
 * Will man das nicht, müssen die nicht verwendeten zuständigen Stellen (des gleichen Datasets)
 * mit einer Query gelöscht werden.
 * 
 * (6) Ein Artcode kann mehrfach vorkommen. Die Kombination Artcode und Artcodeliste (=Namespace) ist
 * eindeutig.  Aufpassen, dass bei den nachfolgenden Queries nicht fälschlicherweise angenommen wird, 
 * dass der Artcode unique ist.
 * Ausnahme: Bei den Symbolen ist diese Annahme materiell richtig (solange eine kantonale aggregierte
 * Form präsentiert wird) und führt zu keinen falschen Resultaten.
 * 
 * (7) 'typ_grundnutzung IN' (etc.) filtern Eigentumsbeschränkungen weg, die mit keinem Dokument verknüpft sind.
 * Sind solche Objekte vorhanden, handelt es sich in der Regel um einen Datenfehler in den Ursprungsdaten.
 * 'publiziertab IS NOT NULL' filtert Objekte raus, die kein Publikationsdatum haben (Mandatory im Rahmenmodell.)
 * 
 * (8) Waldabstandslinien unterscheiden sich nur im Thema/Subthema von den restlichen Linien-Erschliessungsobjekten. 
 * Aus diesem Grund wird kein separates SELECT gemacht, sondern das Thema/Subthema mit CASE/WHEN behandelt.
 *
 * (9) rechtsstatus = inKraft: Die Bedingung hier reicht nicht, damit (spaeter) auch nur die Geometrien verwendet
 * werden, die inKraft sind. Grund dafuer ist, dass es nichtInKraft Geometrien geben kann, die auf einen
 * Typ zeigen, dem Geometrien zugewiesen sind, die inKraft sind. Nur solche Typen, dem gar keine inKraft
 * Geometrien zugewiesen sind, werden hier rausgefiltert. 
 * 
 * (10) Ebenfalls reicht die Bedingung 'inKraft' bei den Dokumenten nicht. Hier werden nur Typen rausgefiltert, die 
 * nur Dokumente angehängt haben, die NICHT inKraft sind. Sind bei einem Typ aber sowohl inKraft wie auch nicht-
 * inKraft-Dokumente angehängt, wird korrekterweise der Typ trotzdem verwendet. Bei den Dokumenten muss der
 * Filter nochmals gesetzt werden.
 */

INSERT INTO 
    arp_npl_oereb.transferstruktur_eigentumsbeschraenkung
    (
        t_id,
        t_basket,
        t_datasetname,
        aussage_de,
        thema,
        subthema,
        artcode,
        artcodeliste,
        rechtsstatus,
        publiziertab,
        zustaendigestelle
    )
    -- Grundnutzung
    SELECT
        DISTINCT ON (typ_grundnutzung.t_ili_tid)
        typ_grundnutzung.t_id,
        basket_dataset.basket_t_id,
        basket_dataset.datasetname,
        typ_grundnutzung.bezeichnung AS aussage_de,
        'Nutzungsplanung' AS thema,
        'ch.SO.NutzungsplanungGrundnutzung' AS subthema,
        typ_grundnutzung.code_kommunal AS artcode,
        'urn:fdc:ilismeta.interlis.ch:2017:NP_Typ_Kanton_Grundnutzung.'||typ_grundnutzung.t_datasetname AS artcodeliste,
        grundnutzung.rechtsstatus,
        grundnutzung.publiziertab, 
        amt.t_id AS zustaendigestelle
    FROM
        arp_npl.nutzungsplanung_typ_grundnutzung AS typ_grundnutzung
        LEFT JOIN arp_npl_oereb.vorschriften_amt AS amt
        ON typ_grundnutzung.t_datasetname = RIGHT(amt.t_ili_tid, 4)
        LEFT JOIN arp_npl.nutzungsplanung_grundnutzung AS grundnutzung
        ON typ_grundnutzung.t_id = grundnutzung.typ_grundnutzung,
        (
            SELECT
                basket.t_id AS basket_t_id,
                dataset.datasetname AS datasetname               
            FROM
                arp_npl_oereb.t_ili2db_dataset AS dataset
                LEFT JOIN arp_npl_oereb.t_ili2db_basket AS basket
                ON basket.dataset = dataset.t_id
            WHERE
                dataset.datasetname = '2491' 
        ) AS basket_dataset
    WHERE 
        typ_grundnutzung.t_datasetname = '2491'
        AND
        typ_kt NOT IN 
        (
            'N180_Verkehrszone_Strasse',
            'N181_Verkehrszone_Bahnareal',
            'N182_Verkehrszone_Flugplatzareal',
            'N189_weitere_Verkehrszonen',
            'N210_Landwirtschaftszone',
            'N320_Gewaesser',
            'N329_weitere_Zonen_fuer_Gewaesser_und_ihre_Ufer',
            'N420_Verkehrsflaeche_Strasse', 
            'N421_Verkehrsflaeche_Bahnareal', 
            'N422_Verkehrsflaeche_Flugplatzareal', 
            'N429_weitere_Verkehrsflaechen', 
            'N430_Reservezone_Wohnzone_Mischzone_Kernzone_Zentrumszone',
            'N431_Reservezone_Arbeiten',
            'N432_Reservezone_OeBA',
            'N439_Reservezone',
            'N440_Wald'
        )
        AND
        typ_grundnutzung.t_id IN 
        (
            SELECT
                DISTINCT ON (typ_grundnutzung) 
                typ_grundnutzung
            FROM
                arp_npl.nutzungsplanung_typ_grundnutzung_dokument AS typ_grundnutzung_dokument
                LEFT JOIN arp_npl.rechtsvorschrften_dokument AS dokument
                ON dokument.t_id = typ_grundnutzung_dokument.dokument
            WHERE
                dokument.rechtsstatus = 'inKraft'        
        )  
        AND
        grundnutzung.publiziertab IS NOT NULL
        AND
        grundnutzung.rechtsstatus = 'inKraft'
;



/*
 * Updaten der Staatskanzlei-TID.
 * 
 * Weil im Vorschriftenmodell die Rolle in der Dokumenten-Amt-Beziehung nicht
 * EXTERNAL ist, taucht jetzt die Staatskanzlei mehrfach auf. Einmal bei den
 * Gesetzen und dann wohl bei jedem Thema bei den RRB. Applikatorisch ist
 * das soweit kein Beinbruch, schmerzt aber trotzdem, da man die Daten
 * nicht mehr komplett auf Modellkonformität prüfen kann (Bundesgesetze + 
 * kantonale Gesetze + Daten). In diesem Fall gibt es die TID "ch.so.sk" 
 * mehrfach. Aus diesem Grund muss bei den Daten die TID der Staatskanzlei
 * jeweils verändert werden. Erst jedoch ganz am Schluss, damit mit beim
 * Datenumbau selber immer nur auf "ch.so.sk" verweisen kann.
 * 
 * Weil die zuständigen Stellen wie auch die Gesetze bei jedem Umbau
 * wieder neu importiert werden, muss die t_ili_tid nicht mehr zurück
 * gesetzt werden.
 */ 

UPDATE 
    arp_npl_oereb.vorschriften_amt
SET
    t_ili_tid = 'ch.so.sk.'||uuid_generate_v4()
WHERE
    t_datasetname = 'ch.so.arp.nutzungsplanung'
AND
    t_ili_tid = 'ch.so.sk'
;