# L2J Mobius Interlude — Docker deployment

This repository contains a Docker Compose deployment for the Lineage 2
Interlude login server, game server, and MySQL database. The L2J source and
datapack are under:

```text
L2J_Mobius_CT_0_Interlude github/
```

Compose and `.env.example` live in the repository root; the Dockerfile and
entrypoint helpers live under `docker/`. The server is built and run with Java
25. A full JDK is used at runtime because L2J dynamically compiles datapack
scripts when the game server starts.

## Services and ports

| Service | Purpose | Exposed TCP port |
| --- | --- | ---: |
| `database` | MySQL 8.4 | Not exposed to the host |
| `login-server` | Client authentication/server list | `2106` |
| `game-server` | Lineage 2 game traffic | `7777` |

The game server connects to the login server on the private Compose network.
MySQL is also available only on that network.

## Linux requirements

Install Docker Engine with the Compose plugin using the instructions for your
Linux distribution. Confirm both commands work:

```bash
docker --version
docker compose version
```

If the current user cannot access Docker, either configure Docker's `docker`
group or run the Docker commands with `sudo`.

The examples below assume the repository is located at:

```text
/home/YOUR_USER/l2-interlude
```

Replace that path with the actual deployment path.

## Configure the deployment

Change to the repository root and create the environment file:

```bash
cd /home/YOUR_USER/l2-interlude
cp .env.example .env
nano .env
```

Example `.env`:

```dotenv
DB_NAME=l2jmobiusinterlude
DB_USER=l2j
DB_PASSWORD=replace-with-a-long-random-password
DB_ROOT_PASSWORD=replace-with-a-different-long-random-password
SERVER_ADDRESS=192.168.1.50
```

`SERVER_ADDRESS` is the address that the login server advertises to game
clients. It is different for each installation:

- Same Linux machine: `127.0.0.1`
- Clients on the same LAN: the server's LAN address, such as `192.168.1.50`
- Internet clients: the router's public IP address or a DNS hostname

Find the Linux machine's addresses with:

```bash
ip -br address
```

When serving players over the internet, forward TCP ports `2106` and `7777`
from the router to the Linux machine. Also allow them through the host firewall.
For example, with UFW:

```bash
sudo ufw allow 2106/tcp
sudo ufw allow 7777/tcp
```

Do not expose MySQL port `3306` to the internet.

## Build and start

From the repository root:

```bash
docker compose up -d --build
```

The first build can take several minutes. It downloads Java/MySQL images and
compiles the Java server. The compiled jars and dependency libraries are baked
into the runtime image; the datapack is mounted from the checkout.

Check status and follow startup logs:

```bash
docker compose ps
docker compose logs -f login-server game-server
```

Stop the stack without deleting its database:

```bash
docker compose down
```

Restart existing containers:

```bash
docker compose restart
```

## Applying server configuration and source changes

The current Docker setup bind-mounts `dist/game` and `dist/login` read-write
from the host. This keeps editable datapack and configuration files out of the
image and allows in-game/runtime actions to persist changes back into the Git
checkout. At startup, the entrypoint creates a container-local configuration
copy and symlinks the rest of the mounted datapack.

The `config` subdirectory is the deliberate exception: it is copied locally so
Docker can inject database credentials and host-specific addresses without
writing secrets or machine-specific values into tracked files. Runtime writes
elsewhere under `dist/game` or `dist/login` follow writable symlinks and persist
on the host.

Game configuration files are located under:

```text
L2J_Mobius_CT_0_Interlude github/dist/game/config/
```

Login configuration files are located under:

```text
L2J_Mobius_CT_0_Interlude github/dist/login/config/
```

After changing configuration, scripts, XML, HTML, or other files under
`dist/game` or `dist/login`, restart the affected container. No image rebuild
is required because these files are mounted:

```bash
docker compose restart game-server
```

Restart both when both mounted trees changed:

```bash
docker compose restart login-server game-server
```

Java files under `L2J_Mobius_CT_0_Interlude github/java` are compiled into the
server jars. Java source changes therefore require rebuilding and recreating
the server image:

```bash
docker compose up -d --build --force-recreate login-server game-server
```

Changes to dependency jars under `dist/libs`, `docker/Dockerfile`, or
`docker/entrypoint.sh` also require an image rebuild. These operations preserve
the MySQL volume.

Important behavior:

- `dist/game/config/Database.ini` is rewritten inside the container at startup
  using the values from `.env`.
- `dist/game/config/Server.ini` has `LoginHost` rewritten to the Compose service
  name at startup.
- `dist/game/config/ipconfig.xml` is generated at startup using
  `SERVER_ADDRESS`.
- The equivalent database settings for the login server are also generated at
  startup.
- Therefore, database host/credentials and the advertised client address
  should be changed in `.env`, not hard-coded in those generated fields.
- Other settings in `dist/game/config`, such as rates or gameplay options, are
  copied from the writable mount each time the container starts. They require
  a container restart but no image rebuild.

After changing only `.env` or `compose.yaml`, source recompilation is not
normally needed, but the containers must be recreated so they receive the new
environment:

```bash
docker compose up -d --force-recreate login-server game-server
```

Using `--build` as well is safe when unsure.

### Database SQL changes

SQL files under `dist/db_installer/sql` are bind-mounted read-only. They
run only when MySQL initializes an empty `l2j-database` volume. Editing a SQL
file or restarting MySQL does not re-import it into an existing database.

Apply a schema migration manually to an existing database, or deliberately
start over with:

```bash
docker compose down -v
docker compose up -d --build
```

**Warning:** `docker compose down -v` permanently removes all accounts,
characters, inventories, and world state. Back up the database first when the
data matters.

## Patch `l2.ini` for the new server address

The Interlude client normally reads its login-server address from the encrypted
`system/l2.ini`. It must advertise the same reachable address configured as
`SERVER_ADDRESS` on the server.

Use the open-source
[ritsuwastaken/open-l2encdec](https://github.com/ritsuwastaken/open-l2encdec)
CLI. Download the latest binary from its
[release page](https://github.com/ritsuwastaken/open-l2encdec/releases/latest),
or build the CLI from source according to its upstream documentation.

First, close the client and back up its original file:

```bash
cd /path/to/Lineage-II/system
cp l2.ini l2.ini.original
```

Decode it. The CLI detects the protocol from the encrypted header:

```bash
/path/to/l2encdec -c decode -o l2.decoded.ini l2.ini
```

The command prints the detected protocol. Record that number. Interlude files
commonly use protocol `413`, but use the value reported for the actual client
instead of assuming it.

Open `l2.decoded.ini` in an editor that preserves its text encoding. Find the
`ServerAddr` setting and replace `127.0.0.1` with the same address clients use
to reach Docker. For example:

```ini
ServerAddr=192.168.1.50
```

Do not set this to a Docker container address such as `172.x.x.x`; use the
Linux host's LAN/public address or DNS name. Leave the login port at `2106`
unless the Compose port mapping was intentionally changed.

Re-encode using the protocol reported during decoding. For protocol `413`:

```bash
/path/to/l2encdec -c encode -p 413 -o l2.patched.ini l2.decoded.ini
mv l2.patched.ini l2.ini
```

If another protocol was detected, replace `413` in that command. Keep the
original filename `l2.ini` when installing the encoded result. If the client
stops launching, restore the backup and repeat the process without changing the
decoded file's encoding:

```bash
cp l2.ini.original l2.ini
```

Never run an untrusted `l2.exe`, patcher, or encryption utility as an
administrator.

## Run the Interlude client on Linux with Steam and Proton 9.0

1. Install and start the Linux version of Steam.
2. In Steam, select **Games → Add a Non-Steam Game to My Library**.
3. Browse to the Interlude client's `system` directory and select `l2.exe`.
   If the file chooser filters it out, select **All Files**.
4. Find the newly added entry in the Steam library, open **Properties**, and
   optionally rename it to “Lineage 2 Interlude”.
5. Under **Compatibility**, enable **Force the use of a specific Steam Play
   compatibility tool**.
6. Select **Proton 9.0**.
7. Launch the game from Steam.

If Steam cannot find game resources, open the shortcut's **Properties** and
verify:

- **Target** points to the client's `system/l2.exe`.
- **Start In** points to the client's `system` directory.
- Both paths are quoted when they contain spaces.

Patch `l2.ini` before starting the client. The Linux client machine must be
able to reach the Docker host on TCP ports `2106` and `7777`.

Proton creates a separate compatibility prefix for the non-Steam shortcut.
Deleting and re-adding the shortcut can create a different prefix, so test
configuration changes before removing a working library entry.

## Updating and troubleshooting

After pulling updates, rebuild if Java, dependencies, or Docker implementation
files changed; otherwise restart the services to reload mounted datapack files:

```bash
docker compose up -d --build --force-recreate
docker compose logs -f login-server game-server
```

Useful checks:

```bash
docker compose ps
docker compose logs --tail=200 database
docker compose logs --tail=200 login-server
docker compose logs --tail=200 game-server
ss -lnt | grep -E ':2106|:7777'
```

Common problems:

- **Client sees `127.0.0.1`:** update `SERVER_ADDRESS`, recreate the game
  server, and patch the client's `l2.ini` to the same reachable address.
- **Database authentication fails after changing `.env`:** an existing MySQL
  volume retains the credentials created during its first initialization.
  Change the MySQL user password in the existing database or restore the old
  `.env` password; do not erase the volume casually.
- **`JavaCompiler` is null:** rebuild with the provided Dockerfile, whose
  runtime stage uses `eclipse-temurin:25-jdk-noble`, not a JRE image.
- **A configuration edit has no effect:** restart the relevant container. The
  writable runtime configuration copy is regenerated from the mount only when
  its entrypoint starts.

## Security notes

- Use strong, different database user and root passwords.
- Keep `.env` private and do not commit it.
- Expose only TCP `2106` and `7777` unless another service is intentionally
  required.
- Back up the `l2-interlude_l2j-database` volume or use `mysqldump` before
  upgrades and schema changes.
