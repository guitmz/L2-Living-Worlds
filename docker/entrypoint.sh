#!/bin/sh
set -eu

: "${SERVER_TYPE:?SERVER_TYPE must be either login or game}"
: "${DB_HOST:=database}"
: "${DB_PORT:=3306}"
: "${DB_NAME:=l2jmobiusinterlude}"
: "${DB_USER:=l2j}"
: "${DB_PASSWORD:=l2j}"

case "$SERVER_TYPE" in
  login) source_dir=/opt/l2j-dist/login; server_dir=/opt/l2j/login; jar=LoginServer.jar ;;
  game)  source_dir=/opt/l2j-dist/game;  server_dir=/opt/l2j/game;  jar=GameServer.jar ;;
  *) echo "Unsupported SERVER_TYPE: $SERVER_TYPE" >&2; exit 64 ;;
esac

if [ ! -d "$source_dir/config" ]; then
  echo "Missing mounted server files at $source_dir" >&2
  exit 66
fi

# Expose the writable dist tree to the server so runtime changes persist back
# to the checkout. Config is copied into a container-local runtime directory
# because database credentials and host-specific network values are injected
# below; all other datapack entries are writable symlinks to the host checkout.
rm -rf "$server_dir"
mkdir -p "$server_dir/config" "$server_dir/log"
cp -R "$source_dir/config/." "$server_dir/config/"
for item in "$source_dir"/*; do
  case "$(basename "$item")" in
    config|log) continue ;;
  esac
  ln -s "$item" "$server_dir/$(basename "$item")"
done

db_config="$server_dir/config/Database.ini"
jdbc_url="jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?useUnicode=true&characterEncoding=utf-8&allowPublicKeyRetrieval=true&useSSL=false&connectTimeout=10000&interactiveClient=true&sessionVariables=wait_timeout=600,interactive_timeout=600&autoReconnect=true"

# Escape values used in sed replacements. In particular, an unescaped "&"
# expands to the entire matched line and corrupts JDBC query parameters.
sed_replacement() {
  printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

jdbc_url_escaped=$(sed_replacement "$jdbc_url")
db_user_escaped=$(sed_replacement "$DB_USER")
db_password_escaped=$(sed_replacement "$DB_PASSWORD")
sed -i \
  -e "s|^URL *=.*|URL = $jdbc_url_escaped|" \
  -e "s|^Login *=.*|Login = $db_user_escaped|" \
  -e "s|^Password *=.*|Password = $db_password_escaped|" \
  "$db_config"

if [ "$SERVER_TYPE" = login ]; then
  sed -i 's|^LoginHostname *=.*|LoginHostname = 0.0.0.0|' "$server_dir/config/Server.ini"
else
  : "${LOGIN_HOST:=login-server}"
  : "${SERVER_ADDRESS:=127.0.0.1}"
  login_host_escaped=$(sed_replacement "$LOGIN_HOST")
  sed -i "s|^LoginHost *=.*|LoginHost = $login_host_escaped|" "$server_dir/config/Server.ini"
  cat > "$server_dir/config/ipconfig.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<gameserver address="$SERVER_ADDRESS" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="../data/xsd/ipconfig.xsd">
  <define subnet="127.0.0.0/8" address="$SERVER_ADDRESS" />
  <define subnet="10.0.0.0/8" address="$SERVER_ADDRESS" />
  <define subnet="172.16.0.0/12" address="$SERVER_ADDRESS" />
  <define subnet="192.168.0.0/16" address="$SERVER_ADDRESS" />
</gameserver>
EOF
fi

cd "$server_dir"
exec java $(cat java.cfg) -jar "../libs/$jar"
