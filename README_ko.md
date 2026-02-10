# more-loop

[English](README.md)

`claude` CLI를 while 루프로 감싸는 반복적 개발 스크립트.

## 작동 방식

1. **Bootstrap** — Claude가 스펙 파일을 읽고 `acceptance.md`(완료 기준)와 `tasks.md`(구현 단계)를 `- [ ]` 체크리스트로 생성
2. **Loop** — 매 iteration: 태스크 하나 선택 → 구현 → 검증. 검증 실패 시 되돌리고 다음 iteration에서 재시도.
3. **Improve** — N회 전에 모든 태스크가 완료되면 개선 작업(리팩토링, 테스트 등)을 수행

매 iteration은 `--permission-mode bypassPermissions`를 가진 새로운 `claude -p` 프로세스. 상태는 `.more-loop/<run-name>/` 내 파일로 전달됩니다.

## 전체 워크플로우 안내

간단한 계산기 API를 구축하는 과정을 통해 more-loop가 실제로 어떻게 작동하는지 살펴보겠습니다.

### Step 1: 스펙 작성

```bash
# 대화형 위자드로 스펙 파일 생성
/more-loop-prompt calculator-api
```

질문에 답변:
- **무엇을 만들까요?** → "계산기를 위한 REST API"
- **기술 스택은?** → "Python, FastAPI, pytest"
- **핵심 기능은?** → "add, subtract, multiply, divide 엔드포인트"

이렇게 하면 `.more-loop/runs/calculator-api/prompt.md`가 생성됩니다.

### Step 2: (선택사항) 검증 계획 작성

```bash
# 대화형 위자드로 검증 생성
/more-loop-verify calculator-api
```

정확성을 검증하는 방법 정의:
- **테스트 통과?** → `pytest tests/ -v`
- **API 작동?** → `curl http://localhost:8000/calculate`
- **타입 체크?** → `mypy .`

이렇게 하면 `.more-loop/runs/calculator-api/verify.sh`가 생성됩니다.

### Step 3: Oracle과 함께 실행 (권장!)

```bash
# --oracle 플래그가 Test-First Architect를 활성화합니다
more-loop --oracle -n 10 calculator-api verify.sh
```

**다음 단계가 진행됩니다:**

#### Phase 1: Bootstrap
- Claude가 `prompt.md`를 읽음
- `acceptance.md` (완료 기준) 생성
- `tasks.md` (구현 단계) 생성
- 예시 태스크:
  ```
  - [ ] FastAPI 프로젝트 구조 설정
  - [ ] /calculate 엔드포인트 구현
  - [ ] add, subtract, multiply, divide 연산 추가
  - [ ] 입력 검증 추가
  - [ ] 유닛 테스트 작성
  ```

#### Phase 2: Oracle (NEW!)
- Claude가 **Test-First Architect**로 작동
- 5가지 레벨을 안내:

**Level 1: Syntax (실행되는가?)**
```
Oracle: "어떤 빌드 명령이 통과해야 할까요?"
You: "pytest tests/가 통과해야 하고 mypy .가 성공해야 해요"

Oracle: "어떤 타입 체크를 할까요?"
You: "Python 3.11+에 strict 모드로요"

Oracle: "린트는요?"
You: "ruff check .에 경고가 없어야 해요"
```

**Level 2: I/O (작동하는가?)**
```
Oracle: "핵심 함수는 무엇인가요?"
You: "add(a, b)는 합계를 반환, divide(a, b)는 몫을 반환하거나 에러를 발생시켜요"

Oracle: "엣지 케이스는요?"
You: "divide by zero는 ZeroDivisionError 발생, 음수 나누기는 정상 작동"
```

**Level 3: Property (어떤 불변식이 있는가?)**
```
Oracle: "수학적 성질은 무엇인가요?"
You: "모든 a, b에 대해: add(a, b) == add(b, a) (교환법칙)"
```

**Level 4: Formal (비즈니스 규칙)**
```
Oracle: "비즈니스 제약조건은?"
You: "결과는 항상 유한한 수여야 함 (NaN이나 Infinity 허용 안 함)"
```

**Level 5: Semantic (사용자 의도)**
```
Oracle: "사용자 시나리오는?"
You: "유효한 숫자가 주어졌을 때, 사용자가 operation='add'로 POST /calculate를 보내면
       100ms 내에 합계를 받아야 해요"
```

- Oracle이 모든 기준을 포함한 `test-guide.md` 생성
- 이것이 구현을 위한 "정답지"가 됩니다!

#### Phase 3: 태스크 반복

이제 각 iteration은 Test Guide를 컨텍스트로 받습니다:

```bash
Iteration 1: "FastAPI 프로젝트 구조 설정"
```

Claude는 다음을 확인:
```
## Test Guide (Oracle 출력):
### Level 1: Syntax
- [ ] pytest tests/ 통과
- [ ] mypy . 통과

### Level 2: I/O
- [ ] add(a, b)는 합계 반환
...
```

그래서 Claude **알고** 있습니다:
- pytest 설정이 포함된 `pyproject.toml` 생성
- `mypy` 설정 추가
- 프로젝트 구조 설정

```bash
Iteration 2: "/calculate 엔드포인트 구현"
```

Claude는 Test Guide를 보고 알게 됨:
- POST 요청 수락
- 입력 검증
- JSON 결과 반환
- divide by zero 처리

#### Phase 4: Audit (모든 태스크 완료 시)

모든 태스크가 체크되면 Claude가 **실제 코드**를 검토:
- 구현 파일 읽기
- 각 태스크 평가: SOLID / WEAK / INCOMPLETE
- 구체적 이슈 식별

#### Phase 5: Improve (남은 iteration)

Audit에서 발견된 이슈를 Claude가 수정:
- "발견: multiply()에 음수 처리 없음"
- "수정 완료: 검증과 적절한 에러 메시지 추가"

### Step 4: 결과 확인

완료 후 `.more-loop/runs/calculator-api/`를 확인:

```bash
.more-loop/runs/calculator-api/
├── prompt.md           # 원래 스펙
├── acceptance.md       # 완료 기준 (모두 체크 ✓)
├── tasks.md            # 구현 단계 (모두 체크 ✓)
├── test-guide.md       # Oracle에서 작성한 Test Guide
├── iterations/
│   ├── 0-bootstrap.md
│   ├── 1.md             # 태스크 1 구현
│   ├── 1-verify.md     # 검증 결과
│   ├── 2.md             # 태스크 2 구현
│   ...
│   └── audit.md         # Audit 결과
└── state.json          # 전체 상태 기록
```

### Oracle 사용의 핵심 장점

**Oracle 없이:**
- "코드가 잘 되어 있기를 바란다"
- 테스트 중 이슈 발견 (너무 늦음!)
- 모호한 완료 기준

**Oracle 사용 시:**
- "'올바름'이 정확히 무엇인지 명세"
- 코딩 전에 Claude가 요구사항을 인지
- 모든 레벨의 구체적이고 테스트 가능한 기준
- Test Guide가 문서화 역할

### 프로 팁

1. **항상 `--oracle` 사용** - 새 프로젝트에서 시간 절약!
2. **Oracle에서 구체적으로** - 모호한 기준은 거절됨
3. **`--approve` 사용** - 구현 시작 전 계획 검토
4. **`test-guide.md` 확인** - Oracle 완료 후 이 파일이 스펙!
5. **`verify.sh` 생성** - 자동화된 테스트가 회귀를 잡음

### 중단된 경우 이어하기

```bash
# Ctrl+C나 에러로 멈췄을 때
more-loop --resume .more-loop/calculator-api -n 5 verify.sh
```

Bootstrap은 건너뛰고, 중단된 지점부터 iteration이 계속됩니다!

## 빠른 시작

```bash
# 레포 클론
git clone <repo-url> && cd more-loop

# 레포에서 직접 실행
./more-loop prompt.md

# 또는 전역 설치
./install.sh
more-loop prompt.md
```

## 설치

### 프로젝트 로컬 (설치 불필요)

레포를 클론하고 `./more-loop`를 직접 실행. 레포 디렉토리에서 작업 시 스킬이 자동으로 검색됩니다.

### install.sh

```bash
./install.sh              # ~/.local/bin/ + ~/.claude/skills/에 설치
./install.sh --uninstall  # 설치된 파일 제거
```

### Makefile

```bash
make install    # 바이너리 + 스킬 복사
make uninstall  # 설치된 파일 제거
make link       # 복사 대신 심링크 (개발용)
make unlink     # 심링크 제거
make help       # 모든 타겟 표시
```

설치 경로 변경: `make install PREFIX=/usr/local`

## 사용법

```
more-loop [OPTIONS] <prompt-file> [verify-file]
more-loop --resume <run-dir> [OPTIONS]
```

### 인수

| 인수 | 설명 |
|------|------|
| `prompt-file` | 구현할 내용을 설명하는 스펙/프롬프트 (필수) |
| `verify-file` | 검증 계획 — `.sh` 스크립트 또는 `.md` 체크리스트 (선택) |

### 옵션

| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `-n, --iterations N` | 5 | 최대 iteration 횟수 |
| `-m, --model MODEL` | opus | 사용할 모델 |
| `--max-tasks N` | auto | Bootstrap 태스크 최대 수 (기본: iterations와 동일, iterations 이하로 클램프) |
| `-v, --verbose` | off | claude 전체 출력 표시 |
| `-w, --web` | off | 웹 대시보드 서버 시작 |
| `-a, --approve` | off | 승인 모드 (매 iteration 후 일시정지) |
| `--approve-timeout N` | 180 | 승인 대기 타임아웃 초 (0 = 무한) |
| `--port PORT` | auto | 웹 서버 포트 |
| `--resume DIR` | | 중단된 실행을 run directory에서 이어하기 |
| `--oracle` | off | Oracle Test-First Architect 단계 활성화 (반복 전) |
| `-h, --help` | | 도움말 표시 |

### 예시

```bash
# 기본: 5 iterations, 기본 모델 (opus)
more-loop prompt.md

# 셸 스크립트 검증 포함
more-loop prompt.md verify.sh

# 마크다운 검증과 커스텀 설정
more-loop -n 10 -m sonnet prompt.md verify.md

# 태스크 수 제한 (retry/improve 여유 확보)
more-loop -n 8 --max-tasks 6 prompt.md verify.sh

# 상세 출력
more-loop -v prompt.md verify.sh

# 중단된 실행 이어하기
more-loop --resume .more-loop/my-project -n 8 -v
```

## 중단된 실행 이어하기

실행이 중단되면 (Ctrl+C, 에러 등) 이전 진행 상황에서 이어할 수 있습니다:

```bash
# 기존 run directory 확인
ls .more-loop/

# 이어하기 — bootstrap 스킵, 10회 추가 iteration 실행
more-loop --resume .more-loop/my-project -n 10

# verify 파일과 함께 이어하기
more-loop --resume .more-loop/my-project -n 10 verify.sh
```

resume 시 `-n`은 **추가 iteration 횟수**입니다 (총 횟수가 아님). `-n 10`이면 이전 실행이 멈춘 지점에서 10회 더 실행합니다.

`--resume`은 run directory의 `tasks.md`, `acceptance.md`, `iterations/*.md`를 읽어 진행 상황을 파악합니다. `-n`, `-m`, `-v` 같은 옵션은 이어할 때 새로 지정 가능합니다.

## 포함된 스킬

이 레포에는 more-loop 입력 파일 생성을 위한 두 가지 Claude Code 스킬이 포함되어 있습니다:

- **`/more-loop-prompt`** — `prompt.md` 스펙 파일 생성 대화형 위자드
- **`/more-loop-verify`** — `verify.sh` 또는 `verify.md` 검증 파일 생성 대화형 위자드

레포 디렉토리에서 작업 시 자동 검색됩니다. `./install.sh` 또는 `make install` 실행 후에는 전역으로 사용 가능합니다.

## Oracle: Test-First Architect 단계

`--oracle` 플래그는 코드를 작성하기 전에 포괄적인 테스트 기준을 정의하는 사전 구현 단계를 활성화합니다. 이는 Test-First Architect 패턴을 따릅니다:

### Oracle이 하는 일

1. **5가지 Oracle 레벨 안내** — Syntax, I/O, Property, Formal, Semantic
2. **구체적인 질문** — 테스트 가능한 기준으로 테스트 가이드 작성
3. **`test-guide.md` 생성** — 작업 반복 중 컨텍스트로 사용됨
4. **완성도 보장** — 모든 레벨에 충분한 기준이 있을 때까지 완료하지 않음

### 5가지 Oracle 레벨

| 레벨 | 질문 | 예시 |
|------|------|------|
| Lv.1: Syntax | 실행되는가? | "빌드 성공, 타입 검사 통과" |
| Lv.2: I/O | 작동하는가? | "add(5, 3)은 8 반환, POST /users는 201 반환" |
| Lv.3: Property | 어떤 불변식이 있는가? | "모든 a, b에 대해: add(a, b) == add(b, a)" |
| Lv.4: Formal | 비즈니스 규칙은? | "계좌 잔액은 음수가 될 수 없음" |
| Lv.5: Semantic | 사용자 의도를 충족하는가? | "로그인한 사용자가 로그아웃하면 로그인 페이지 표시" |

### 사용 예

```bash
# Oracle 단계와 함께
more-loop --oracle prompt.md verify.sh

# Oracle + 승인 모드
more-loop --oracle --approve prompt.md verify.sh
```

전체 Test Guide 예시는 `docs/test-guide-example.md`를 참조하세요.

## LLM 행동 제어

more-loop는 다중 방어 체계로 LLM 행동을 제어합니다:

| 계층 | 메커니즘 | 설명 |
|------|----------|------|
| 시스템 프롬프트 | `--append-system-prompt` | phase별 지시를 주입하여 "하나만 해" 강제 |
| 코드 강제 | `enforce_single_task()` | snapshot 비교 후 초과분을 결정적으로 revert |
| Bootstrap 제한 | `enforce_max_tasks` | 태스크 목록이 제한을 초과하면 잘라냄 |

시스템 프롬프트는 `system-prompts/` 디렉토리에 있으며 phase별로 분리되어 있습니다:

- **`bootstrap.md`** — 태스크 수와 단위 제어
- **`task.md`** — 단일 태스크 프로토콜 강제, 스킬/서브에이전트 활용 안내
- **`improve.md`** — 개선 모드 안내

## 중간 중지

`Ctrl+C`를 누르면 중지됩니다. 현재 `claude` 서브프로세스를 먼저 종료하고 외부 루프를 종료하기 위해 두 번 눌러야 할 수 있습니다.

다른 터미널에서:

```bash
pkill -f more-loop
```

완료된 iteration의 진행 상황은 보존됩니다. 진행 중이던 iteration은 부분 적용될 수 있습니다 — 중지 후 `git status`와 `git log`를 확인하세요. `--resume`으로 이어할 수 있습니다.

## 검증 유형

| 유형 | 확장자 | 작동 방식 | 적합한 용도 |
|------|--------|-----------|-------------|
| 셸 스크립트 | `.sh` | bash로 실행, exit 0 = 통과 | 테스트, 빌드, 린트, 구체적 검사 |
| 마크다운 | `.md` | Claude가 코드베이스 대비 체크리스트 평가 | 코드 품질, 아키텍처, 주관적 기준 |

## 프로젝트 구조

```
more-loop
├── more-loop                          # 메인 실행 파일
├── install.sh                         # 설치/제거 스크립트
├── Makefile                           # install/link Make 타겟
├── system-prompts/                    # phase별 LLM 행동 제어
│   ├── bootstrap.md                   # 태스크 수/단위 제약
│   ├── task.md                        # 단일 태스크 강제
│   └── improve.md                     # 개선 모드 안내
├── .claude/
│   └── skills/
│       ├── more-loop-prompt/SKILL.md  # 프롬프트 생성 스킬
│       └── more-loop-verify/SKILL.md  # 검증 파일 생성 스킬
├── CLAUDE.md                          # Claude Code용 프로젝트 지침
├── README.md                          # English documentation
└── README_ko.md                       # 이 파일
```

## 요구 사항

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (PATH에 `claude`)
- Bash 4+
