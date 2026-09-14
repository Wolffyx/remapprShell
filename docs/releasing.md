# Branches and releases

Two branches, because the updater already understands them. `rmpr update`
installs by following a branch -- `--channel <name>`, main by default -- so a
branch here is a channel someone can be on, not just a place to put commits.

| Branch | What it is | Who is on it |
|--------|------------|--------------|
| `main` | Stable. Moves only when a release is cut. | Anyone who installed and left the default alone. |
| `dev`  | Where work lands. | `rmpr update --channel dev`, and whoever is building. |

So: commit to `dev`, open a pull request into `main` when it is worth other
people having, and cut a release from `main`.

CI runs on both branches and on every pull request. It is the six checks
`make lint` runs plus the test suite -- named one step per check, so a red run
says which one failed without opening the log. A lint added to the Makefile
belongs in `.github/workflows/ci.yml` in the same commit; one that runs
locally and not in CI fails on someone else's machine first.

## Cutting a release

1. Get `main` where you want it -- usually by merging `dev`.
2. Bump `VERSION` on `main`, commit, push.
3. Tag that commit and push the tag:

   ```
   git tag v0.2.0
   git push origin v0.2.0
   ```

The tag is the trigger, not the decision. `release.yml` refuses a tag whose
name disagrees with the `VERSION` file at the commit it points at, because a
version the CLI reports and a version on the forge that differ is the kind of
thing nobody notices until it matters -- and refusing a tag is cheaper than
deleting a published release.

It then runs the whole gate again. A tag can be pushed at any commit,
including one that never went through a pull request, so the release does not
assume CI has already looked at it. If that passes, it publishes a GitHub
release with notes generated from the commits since the previous tag.

Nothing is built or attached. Delivery is git: a release is `main` having
moved, plus a tag naming where it moved to, and `scripts/update.sh` installs
by pulling the branch. An artefact here would be one the updater ignores.

## What is not automated

- **Nothing bumps `VERSION` for you.** Deciding a version is a judgement about
  what changed, and a workflow that guessed would be wrong in exactly the
  cases that matter.
- **Branch protection on `main`** is a repository setting, not a file in the
  tree. Requiring CI to pass before a merge is worth turning on; until it is,
  the workflows report but do not block.
