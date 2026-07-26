# Patch `l2.ini` for a custom server address

The Lineage 2 Interlude client normally reads its login-server address from the
encrypted `system/l2.ini`. It must use the same reachable address configured as
`SERVER_ADDRESS` on the Docker server.

Use the open-source
[ritsuwastaken/open-l2encdec](https://github.com/ritsuwastaken/open-l2encdec)
CLI. Download the latest binary from its
[release page](https://github.com/ritsuwastaken/open-l2encdec/releases/latest),
or build the CLI from source according to its upstream documentation.

## Back up and decode

Close the client and back up its original file:

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

## Change the address

Open `l2.decoded.ini` in an editor that preserves its text encoding. Find the
`ServerAddr` setting and replace `127.0.0.1` with the same address clients use
to reach Docker. For example:

```ini
ServerAddr=192.168.1.50
```

Do not use a Docker container address such as `172.x.x.x`. Use the Linux host's
LAN address, public address, or DNS name. Leave the login port at `2106` unless
the Compose port mapping was intentionally changed.

## Re-encode and install

Re-encode using the protocol reported during decoding. For protocol `413`:

```bash
/path/to/l2encdec -c encode -p 413 -o l2.patched.ini l2.decoded.ini
mv l2.patched.ini l2.ini
```

If another protocol was detected, replace `413` in that command. Keep the
original filename `l2.ini` when installing the encoded result.

If the client stops launching, restore the backup and repeat the process
without changing the decoded file's text encoding:

```bash
cp l2.ini.original l2.ini
```

Never run an untrusted `l2.exe`, patcher, or encryption utility as an
administrator.
