-- Database: mitm

-- DROP DATABASE IF EXISTS mitm;

CREATE DATABASE mitm
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    LOCALE_PROVIDER = 'libc'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

COMMENT ON DATABASE mitm
    IS 'Man in the Middle Data Agregator';

GRANT TEMPORARY, CONNECT ON DATABASE mitm TO PUBLIC;

GRANT ALL ON DATABASE mitm TO mitm_user;

GRANT ALL ON DATABASE mitm TO postgres;