# Step 04: Execute — Run Sync

## Purpose

Ask user for confirmation, then execute the sync.

## Procedure

1. Show what will happen:
   ```
   Sync를 실행합니다:

   Source: ~/.claude → Dest: ~/.codex
   Config: <config_path>
   제외: <exclusion summary>

   먼저 --dry-run으로 미리보기를 보여드릴까요?
   ```

2. If user wants dry-run first:
   ```bash
   bash <path-to>/cc-to-codex.sh --dry-run --config <config_path>
   ```
   Show output, then ask:
   ```
   이대로 실행할까요?
   ```

3. If user confirms (or skips dry-run):
   ```bash
   bash <path-to>/cc-to-codex.sh --config <config_path>
   ```

4. Show results:
   ```
   Sync 완료!
     Changed: N
     Skipped: N
   ```

## Checklist

- [ ] Show sync summary
- [ ] Offer dry-run preview
- [ ] Get user confirmation
- [ ] Execute sync
- [ ] Report results
