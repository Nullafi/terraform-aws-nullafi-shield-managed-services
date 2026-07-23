# Release process (release branch)

Releases are cut from a **release branch**. The Release workflow runs on that branch, updates the changelog and version, then you merge the release branch into `main` via PR. This keeps `main` protected (no direct pushes).

## Step-by-step

1. **Ensure `main` has the work you want released**  
   Merge any `dev` → `main` PRs first so `main` is up to date.

2. **Create a release branch from `main`**
   ```bash
   git fetch origin
   git checkout main
   git pull origin main
   git checkout -b release/1.2.0   # or release/next, release/2024-02-21, etc.
   git push -u origin release/1.2.0
   ```

3. **Let the Release workflow run**  
   On push to `release/*`, the [Release](https://github.com/Nullafi/terraform-aws-nullafi-shield-managed-services/actions/workflows/release.yml) workflow runs. It will:
   - Determine the next version from conventional commits on the branch
   - Update `CHANGELOG.md` and version in `release/package.json`
   - Commit those changes to the release branch (with `[skip ci]` to avoid loops)
   - Create the git tag (e.g. `v1.2.0`) and the GitHub Release

   If there are no releasable commits, the workflow exits without creating a release (no changelog commit).

4. **Merge the release branch into `main`**
   - Open a PR: **base `main`**, compare **release/1.2.0** (or your branch).
   - Review the changelog and version bump.
   - Merge the PR. `main` now has the release commit; no direct push to `main` by the bot.

5. **Optional: delete the release branch**  
   After merging, you can delete the release branch locally and on the remote.

## Notes

- **Conventional commits** on the release branch (and commits merged into it from `main`) drive the version and changelog. Use `feat:`, `fix:`, etc. on `main` before you create the release branch so they’re included.
- **First release:** If there’s no previous tag, semantic-release will choose the version from the history (e.g. 1.0.0 for the first `feat:` or similar).
- **No new release:** If the workflow runs but finds no new releasable commits, it does nothing. You can push more commits to the release branch and re-run, or close the branch and create a new one from `main` later.
