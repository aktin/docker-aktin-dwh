DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'meld2') THEN
        CREATE USER meld2 WITH PASSWORD 'meld';
        GRANT CONNECT, TEMPORARY ON DATABASE i2b2 TO meld;
        GRANT USAGE ON SCHEMA i2b2crcdata TO meld;
        GRANT SELECT ON ALL TABLES IN SCHEMA i2b2crcdata TO meld;
    END IF;
END
$$;

