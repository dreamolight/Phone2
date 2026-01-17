#!/bin/bash
# Script to setup PostgreSQL database with UTF8 and correct permissions

DB_NAME="sms_sync_db"
DB_USER="postgres" 
# Note: You might need to change DB_USER to your actual superuser if it's not 'postgres'
# On some Mac installs, the default superuser is the system username.

echo "Creating Database $DB_NAME with UTF8 encoding..."
psql postgres -c "CREATE DATABASE $DB_NAME WITH ENCODING 'UTF8';" || echo "Database might already exist"

echo "Changing ownership of database $DB_NAME to $DB_USER..."
# This ensures that the user can create schemas/tables inside the DB.
psql postgres -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"

echo "Granting permissions..."
# Granting all privileges on public schema to the user defined in .env (assuming it connects as 'postgres' or similar)
# If you are using a different user in .env, change 'postgres' below to that user.
psql $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;"
psql $DB_NAME -c "GRANT ALL ON SCHEMA public TO public;"

echo "Done. Try running 'node init_db.js' now."
