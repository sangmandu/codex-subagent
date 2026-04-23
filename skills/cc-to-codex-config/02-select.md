# Step 02: Select — Choose Exclusions

## Purpose

Let the user choose which items to EXCLUDE from sync. Default is sync everything.

## Procedure

### 1. Explain the model

```
기본적으로 모든 항목이 sync됩니다.
제외할 항목만 선택해주세요. (없으면 "없음"이라고 해주세요)
```

### 2. Ask per category

**Skills:**
```
제외할 스킬이 있나요?
번호 또는 이름으로 알려주세요 (쉼표 구분, glob 패턴 가능)
예: wf, poppy-*, mally-local-e2e-test
```

**Hooks:**
```
제외할 훅이 있나요?
번호 또는 파일명으로 알려주세요 (쉼표 구분)
예: rtk-rewrite.sh, record-surface-session.sh
```

**CLAUDE.md sections:**
```
AGENTS.md로 복사하지 않을 섹션이 있나요?
번호 또는 섹션명으로 알려주세요 (쉼표 구분)
예: @RTK.md, Sub-Agent Policy
```

### 3. Confirm selections

```
제외 목록 확인:

[Skills] wf, poppy-*
[Hooks] rtk-rewrite.sh
[CLAUDE.md] @RTK.md

맞으면 진행할게요. 수정할 부분이 있으면 말씀해주세요.
```

Wait for user confirmation before proceeding.

## Checklist

- [ ] Explain default-include model
- [ ] Collect skill exclusions
- [ ] Collect hook exclusions
- [ ] Collect CLAUDE.md section exclusions
- [ ] Present summary and get confirmation
