#!/bin/bash
set -e

mysql=(mysql --protocol=socket -uroot -hlocalhost)
if [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
  mysql+=("-p${MYSQL_ROOT_PASSWORD}")
fi

for schema in login game; do
  for sql_file in /l2j-sql/$schema/*.sql; do
    echo "Importing $sql_file"
    "${mysql[@]}" "$MYSQL_DATABASE" < "$sql_file"
  done
done
