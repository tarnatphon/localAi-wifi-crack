# Repo sync topology

Three places hold this code. Only one of them can be reached from the AI sandbox.

| Place | What it is | Reachable from sandbox? |
|---|---|---|
| **GitHub** — `tarnatphon/localAi-wifi-crack` | Source of truth for `main` | Yes |
| **Sandbox** — `/home/user/localAi-wifi-crack` | Where AI work happens, on `arena/8a00fdc6-localai-wifi-crack` | Yes (self) |
| **Mac** — `/Users/ekky/Desktop/Wifi Crack` | Your local working copy | **No** |

```
  sandbox ──push arena/*──▶ GitHub ──pull──▶ Mac
                              │
                              └──PR merge──▶ main
```

The sandbox has no route to `/Users/ekky/...` — outbound network is allowlisted to
GitHub/npm/PyPI, and your Mac is not addressable from here. So GitHub is the only
meeting point; the Mac never needs to be a remote for me.

## Remotes in this sandbox

```
origin  https://github.com/tarnatphon/localAi-wifi-crack.git   # GitHub
mac     /Users/ekky/Desktop/Wifi Crack                          # placeholder, unreachable here
```

`origin` deliberately stays GitHub: it is how the arena branch gets pushed and how the
PR into `main` is opened. `mac` is registered for documentation/intent only — running
`git fetch mac` here fails with `does not appear to be a git repository`, which is expected.

## On the Mac — one-time setup

The folder `/Users/ekky/Desktop/Wifi Crack` is **not** a git repository — it is a plain
folder. Every `git` command inside it fails with `fatal: not a git repository` until it is
cloned or attached. Use the helper script:

```bash
# from anywhere, e.g. after downloading the script or cloning elsewhere
bash ~/path/to/scripts/mac-setup.sh
```

It is safe to re-run and handles all three states:

| State of the folder | What the script does |
|---|---|
| Already a repo | re-points `origin` to GitHub, fetches, reports branch |
| Empty | `git clone <github> .` — ends on `main` |
| Has files, no `.git` | **refuses**, shows contents, offers two options |
| Has files, `--adopt` | tars to `~/Desktop/Wifi-Crack-backup-<ts>.tar.gz`, then `git init` + reset to `origin/main` |

Or do it by hand in an empty folder:

```bash
cd "/Users/ekky/Desktop/Wifi Crack"     # quotes required, path has a space
git clone https://github.com/tarnatphon/localAi-wifi-crack.git .
git remote -v                           # expect origin -> github.com/tarnatphon/localAi-wifi-crack
git checkout main
```

Order matters: `git clone` must happen **before** any `git fetch`/`git checkout` — those
cannot work in a folder that has no `.git` directory.

## Troubleshooting

**`fatal: not a git repository (or any of the parent directories): .git`**
You are in a plain folder. Run `scripts/mac-setup.sh` (above). Remote commands are
irrelevant until a `.git` exists.

**`&amp;&amp;` in a pasted command**
Chat rendering HTML-escapes `&` as `&amp;`. Type a literal `&&`, or run the commands on
separate lines — `&` alone backgrounds the command and `amp;` is not a command.

**`fatal: destination path '.' already exists and is not an empty directory`**
The folder has files. Move them out, or use `--adopt` to back up and overwrite.

## Daily loop

1. I work in the sandbox, commit to `arena/8a00fdc6-localai-wifi-crack`, push to `origin`.
2. You `git pull` on the Mac — either `git pull origin main` after a merge, or
   `git fetch origin && git checkout arena/8a00fdc6-localai-wifi-crack` to track my branch directly.
3. Anything you commit on the Mac goes up with `git push origin <branch>`; I pick it up by
   fetching from GitHub. Don't try to push to the sandbox.

## Optional: make the Mac folder a push target

Only if you want a second machine to push *into* your Desktop folder. A normal working
copy refuses pushes; allow it with modern Git:

```bash
cd "/Users/ekky/Desktop/Wifi Crack"
git config receive.denyCurrentBranch updateInstead
```

Then from the pushing machine:

```bash
git remote add mac "/Users/ekky/Desktop/Wifi Crack"
git push mac arena/8a00fdc6-localai-wifi-crack
```

`updateInstead` requires the Mac folder to have no uncommitted changes, or the push is rejected.

## Path-with-space gotchas

- Always quote it in the shell: `cd "/Users/ekky/Desktop/Wifi Crack"`.
- Inside `.git/config` no escaping is needed; git stores the literal path.
- Avoid `\ ` backslash-escapes in scripts — they break under some shells.
