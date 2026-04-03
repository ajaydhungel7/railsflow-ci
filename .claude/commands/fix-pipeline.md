Use the gh CLI to check the latest CI pipeline run for this repository, diagnose any failures, fix them, and push the fix.

Follow these steps:

1. Run `gh run list --limit 1` to get the latest run ID and status.

2. If the latest run succeeded, report that the pipeline is passing and stop.

3. If it failed, run `gh run view <run_id> --json jobs --jq '.jobs[] | {name: .name, conclusion: .conclusion}'` to identify which job(s) failed.

4. For each failed job, get the failure details with `gh run view <run_id> --log-failed 2>&1 | grep -E "##\[error\]|error:|Error|cannot|failed|refused|not found" | head -40` to find the root cause.

5. Read the relevant workflow file(s) and any referenced scripts or application files to understand the problem.

6. Fix the issue by editing the appropriate file(s).

7. Commit with a concise message describing the fix (no Co-Authored-By footer).

8. Push to main and report what was fixed.

If the error requires infrastructure changes (EKS cluster not running, AWS resource missing), report that clearly instead of trying to fix it in code.
