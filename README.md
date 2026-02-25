# Fighting Gold — Godot 4 Roguelike Auto-Battler (MVP)

Вертикальный срез 1v1 авто-баттлера с конструктором комбо, правилами поведения и рогалик-наградами.

## Запуск
1. Откройте проект в **Godot 4.x** (`project.godot`).
2. Нажмите **Play**.
3. Игровой цикл:
   - Main Menu → **Start Run**
   - Preparation Screen: выберите/соберите комбо и оцените risk/reward
   - Fight Screen: авто-бой 1v1 с читаемыми фазами и телеграфами
   - Reward Screen: выберите 1 из 3 апгрейдов
   - При смерти → Game Over → Main Menu

## Что уже играбельно
- Полный loop забега: меню → подготовка → бой → награда → следующий бой / game over.
- Бой с commitment (startup/active/recovery), punish windows, guard break, poise/stagger, stamina pressure.
- Приоритетные правила автобоя игрока (top priority wins).
- 3 архетипа врагов: Bruiser / Duelist / Tank.
- Placeholder-визуал бойцов + telegraph label + hit-stop/camera shake hooks.
- Добавлены анимации ударов: lunge, hit reaction, slash-trails и impact flash.

## Структура проекта
- `battle/` — state machine бойцов, combat loop, hit resolution.
- `ai/` — AI игрока (приоритетные правила), AI врагов.
- `data/json/` — data-driven контент (moves, enemies, upgrades).
- `ui/` — логика экранов.
- `run/` — roguelike loop, состояние забега, применение апгрейдов.
- `fx/` — сигналы под hit-stop/camera shake/telegraph.
- `scenes/` — экраны игры.

## Data-driven контент
### Добавить новый прием
1. Откройте `data/json/moves.json`.
2. Добавьте запись с параметрами:
   - `name`, `damage`, `stamina_cost`,
   - `startup_frames`, `active_frames`, `recovery_frames`,
   - `range`, `move_forward_distance`,
   - `hit_stun`, `block_stun`, `guard_damage`, `poise_damage`,
   - `tags`, `combo_rules`, `on_hit`, `on_block`, `on_whiff`.
3. Добавьте id приема в комбо или откройте через upgrade с `effect: unlock_move`.

### Добавить нового врага
1. Откройте `data/json/enemies.json`.
2. Добавьте запись со `style`, `stats`, `move_pool`, `signature`.

### Добавить апгрейд
1. Откройте `data/json/upgrades.json`.
2. Добавьте объект с `id`, `name`, `desc`, `effect`, `value` (+ `tag`/`move_id` при необходимости).
3. Добавьте обработку эффекта в `run/run_manager.gd` при необходимости.
