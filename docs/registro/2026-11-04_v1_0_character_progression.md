# Registro — Character Progression V1.0 (Vertical Slice Completo)

## Status das Etapas (A até H)
- **Etapa A (Auditoria e Higiene):** Concluída. Aplicadas correções da v0.20.1 (`arena_art.gd`, `enemy.gd`, `player.gd`, `wolf_enemy.gd`) e proteção de `visual` nula em `enemy.gd` para execução segura em testes headless.
- **Etapa B (Contratos e Atributos):** Concluída (`StatModifier`, `CharacterStats`, `CharacterDefinition`, `AbilityDefinition`, `AbilityRuntimeState`).
- **Etapa C (XP e Níveis):** Concluída (`ProgressionBalance`, `RunProgressionState`, `RunProgressionService`).
- **Etapa D (Gerador de Ofertas):** Concluída (`ProgressionUpgradeDefinition`, `ProgressionOfferGenerator`, `UpgradeCatalog`).
- **Etapa E (Transformações e Combate):** Concluída (`TowerAttackController` com `STAB`, `ARC`, `SPIN`, `PIERCE`, DoT de Queimadura, Golpe Ecoante sem recursão e VFX v0.20 integrados).
- **Etapa F (Progressão Permanente e Save):** Concluída (`RunSummaryState`, `RunRewardCalculator`, `TalentNodeDefinition`, `PermanentProgressionState`, `PermanentProgressionService`, `SaveService`).
- **Etapa G (UI e Loop Completo):** Concluída (`RunXpHUD`, `LevelUpModal`, `RunResultModal`, `TalentTreeModal` integrados em `scripts/main.gd`).
- **Etapa H (Testes Automatizados e Validação Headless):** Concluída no Godot Engine v4.7.2.stable.

## Evidências de Testes Executados no Godot 4.7.2
1. `res://tests/progression/test_full_progression_suite.gd`:
   - **28 asserções aprovadas / 0 falhas** cobrindo todos os 18 requisitos da Seção 14 (XP, excedente, múltiplos níveis, ordem de cálculo de atributos, ajuste de vida máxima, expiração de buff temporário, 3 ofertas sem duplicatas, limite de rank, exclusividade Meia-lua vs Perfuração, não-duplicação de transformação, compatibilidade Fogo + Eco, anti-recursão de Eco, limpeza de estado em nova run, concessão única de Essência, compra de talentos, aplicação única da metaprogressão, isolamento de classe Guerreiro vs Mago, persistência JSON, recuperação automática de `.bak` após corrupção de save, Respec com reembolso total, isolamento entre instâncias de `TowerPlayer` e integração real da cena `main.tscn` com `LevelUpModal` e `RunResultModal`).
2. `res://tests/progression/test_run_progression.gd`:
   - **14 asserções aprovadas / 0 falhas** (retrocompatibilidade total com o contrato v0.17).
3. `res://tests/test_enemy_reference.gd`:
   - **Aprovado sem vazamentos de memória ou erros de nó ausente.**
