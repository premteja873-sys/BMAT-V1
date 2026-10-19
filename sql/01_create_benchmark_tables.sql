BEGIN;

DO $$
DECLARE
    row_total integer;
    index_method text;
    table_name text;
BEGIN
    FOREACH row_total IN ARRAY ARRAY[10000, 100000, 500000]
    LOOP
        FOREACH index_method IN ARRAY ARRAY['noindex', 'bplus', 'hash']
        LOOP
            table_name := format('benchmark_%s_%s', row_total, index_method);

            EXECUTE format('DROP TABLE IF EXISTS %I', table_name);

            EXECUTE format(
                'CREATE TABLE %I (
                    record_id    integer NOT NULL,
                    lookup_key   integer NOT NULL,
                    student_name text NOT NULL,
                    score        integer NOT NULL
                )',
                table_name
            );

            EXECUTE format(
                'INSERT INTO %I (record_id, lookup_key, student_name, score)
                 SELECT n,
                        n * 10 + 7,
                        ''Student_'' || n,
                        n %% 101
                 FROM generate_series(1, %s) AS n',
                table_name,
                row_total
            );

            IF index_method = 'bplus' THEN
                EXECUTE format(
                    'CREATE INDEX %I ON %I USING btree (lookup_key)',
                    table_name || '_lookup_idx',
                    table_name
                );

            ELSIF index_method = 'hash' THEN
                EXECUTE format(
                    'CREATE INDEX %I ON %I USING hash (lookup_key)',
                    table_name || '_lookup_idx',
                    table_name
                );
            END IF;

            EXECUTE format('ANALYZE %I', table_name);
        END LOOP;
    END LOOP;
END $$;

COMMIT;
