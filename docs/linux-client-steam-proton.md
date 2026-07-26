# Run Lineage 2 Interlude on Linux with Steam and Proton

This guide runs the Windows Interlude client through Steam using the Proton 9.0
compatibility layer.

Before starting, patch the client address by following the
[`l2.ini` patching guide](l2-ini-patching.md). The Linux client machine must be
able to reach the Docker host on TCP ports `2106` and `7777`.

## Add the client to Steam

1. Install and start the Linux version of Steam.
2. Select **Games → Add a Non-Steam Game to My Library**.
3. Browse to the Interlude client's `system` directory and select `l2.exe`.
   If the file chooser filters it out, select **All Files**.
4. Find the newly added entry in the Steam library and open **Properties**.
5. Optionally rename it to “Lineage 2 Interlude”.

## Select Proton 9.0

1. Open the shortcut's **Properties**.
2. Select **Compatibility**.
3. Enable **Force the use of a specific Steam Play compatibility tool**.
4. Select **Proton 9.0**. Other versions are likely to work as well, test at your will.
5. Launch the game from Steam.

## Check the executable paths

If Steam cannot find the game resources, open the shortcut's **Properties** and
verify:

- **Target** points to the client's `system/l2.exe`.
- **Start In** points to the client's `system` directory.
- Both paths are quoted when they contain spaces.

## Proton prefix behavior

Proton creates a separate compatibility prefix for the non-Steam shortcut.
Deleting and re-adding the shortcut can create a different prefix, so test
configuration changes before removing a working library entry.

If changing the executable path or client installation causes Proton to behave
like a fresh installation, recheck the shortcut and compatibility settings
before deleting any prefix data.
