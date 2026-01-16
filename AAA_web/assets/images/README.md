# 미니게임 애셋 이미지 가이드

## 필요한 이미지 파일들:

### 플레이어 (32x32px):
- `player/worker_idle_down.png` - 직장인 기본 모습 (아래)
- `player/worker_run_down.png` - 직장인 달리기 (아래)
- `player/worker_idle_up.png` - 직장인 기본 모습 (위)
- `player/worker_run_up.png` - 직장인 달리기 (위)
- `player/worker_idle_left.png` - 직장인 기본 모습 (왼쪽)
- `player/worker_run_left.png` - 직장인 달리기 (왼쪽)
- `player/worker_idle_right.png` - 직장인 기본 모습 (오른쪽)
- `player/worker_run_right.png` - 직장인 달리기 (오른쪽)
- `player/attack_*.png` - 공격 애니메이션

### 적 (다양한 크기):
- `enemies/deadline_monster.png` - 데드라인 몬스터 (48x48px)
- `enemies/meeting_goblin.png` - 회의 고블린 (32x32px)
- `enemies/bug_spider.png` - 버그 거미 (24x24px)
- `enemies/*_attack.png` - 각각의 공격 애니메이션

### 오브젝트:
- `objects/coffee_machine.png` - 커피머신
- `objects/desk.png` - 책상

### 맵:
- `maps/office_map.tmj` - 사무실 맵 파일 (Tiled 에디터)

## 임시 대체 방안:
현재는 단색 사각형으로 대체하여 게임 로직을 먼저 구현하고,
나중에 실제 스프라이트로 교체할 수 있습니다.