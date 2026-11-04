# Arquitetura e Contratos — Character Progression V1.0

## 1. Visão Geral das Três Camadas
O sistema de progressão foi projetado e implementado em três camadas independentes e desacopladas da interface e dos modelos 3D:

1. **Run Progression (`core/progression/`)**: estado temporário exclusivo de cada tentativa (`RunProgressionState`), curva de experiência configurável (`ProgressionBalance`), fila de escolhas pendentes e gerador determinístico de 3 ofertas (`ProgressionOfferGenerator`).
2. **Ability Evolution (`core/abilities/` + `content/progression/upgrades/`)**: separação estrita entre a definição estática imutável (`AbilityDefinition`) e o estado mutável da partida (`AbilityRuntimeState`), suportando comportamentos substitutos (`STAB`, `ARC`, `SPIN`, `PIERCE`), melhorias de alcance/alvos e modificadores especiais (`burn`, `echo`) com trava contra recursão infinita.
3. **Meta Progression (`game/progression/` + `game/runs/`)**: cálculo centralizado de recompensas ao fim da tentativa (`RunSummaryState`, `RunRewardCalculator`) com trava `reward_claimed`, árvore ramificada de talentos (`TalentNodeDefinition`, `PermanentProgressionService`) com suporte a Respec e persistência segura em JSON (`SaveService`).

---

## 2. Política Central de Cálculo de Atributos (`CharacterStats`)
Nenhum módulo calcula atributos com fórmulas avulsas. Todo atributo passa por `CharacterStats::_compute_stat(stat_name)`:

1. **Valor-base** (vindo de `CharacterDefinition`).
2. **Bônus planos (`StatModifier.Op.FLAT`)**: somados ao valor-base.
3. **Bônus percentuais aditivos (`StatModifier.Op.PERCENT_ADD`)**: somados entre si e aplicados sobre `(base + flat)`.
4. **Multiplicadores específicos (`StatModifier.Op.MULTIPLY`)**: aplicados sequencialmente sobre o subtotal.
5. **Limites (`STAT_LIMITS`) e arredondamento final**: `clampf(min, max)` e `roundi()` para atributos inteiros (`max_health`, `damage`).

### Regra de Vida Máxima
- Quando `max_health` aumenta durante a partida, `CharacterStats` **preserva a quantidade de vida faltante** (`missing_hp = old_max - current_health`), garantindo que o ganho de vida máxima beneficie imediatamente o jogador.
- Quando um bônus é removido ou expira, `current_health` é limitado ao intervalo válido `[1, new_max]` (se vivo), nunca matando o personagem por expiração de buff.

---

## 3. Contratos e Separação de Dados x Estado

| Componente | Caminho | Tipo | Responsabilidade |
|---|---|---|---|
| `CharacterDefinition` | `core/stats/character_definition.gd` | `Resource` (`.tres`) | Dados estáticos da classe (atributos iniciais, habilidade inicial). |
| `CharacterStats` | `core/stats/character_stats.gd` | `RefCounted` | Estado runtime de atributos e modificadores de uma instância. |
| `StatModifier` | `core/stats/stat_modifier.gd` | `RefCounted` | Modificador individual (`FLAT`, `PERCENT_ADD`, `MULTIPLY`, temporário ou permanente). |
| `AbilityDefinition` | `core/abilities/ability_definition.gd` | `Resource` (`.tres`) | Dados estáticos da habilidade-base. |
| `AbilityRuntimeState` | `core/abilities/ability_runtime_state.gd` | `RefCounted` | Estado mutável da habilidade durante uma tentativa. |
| `ProgressionUpgradeDefinition` | `core/progression/progression_upgrade_definition.gd` | `Resource` (`.tres`) | Dados de cada evolução, requisitos, tags, exclusões e grupo de exclusividade. |
| `RunProgressionState` | `core/progression/run_progression_state.gd` | `RefCounted` | XP, nível, fila de escolhas e histórico de upgrades da partida. |
| `ProgressionOfferGenerator` | `core/progression/progression_offer_generator.gd` | `RefCounted` | Sorteio ponderado de até 3 cartas válidas com `RandomNumberGenerator` e `seed` controlável. |
| `RunProgressionService` | `core/progression/run_progression_service.gd` | `Node` | Coordenação de XP, níveis, ofertas e aplicação de melhorias. |
| `PermanentProgressionState` | `game/progression/permanent_progression_state.gd` | `RefCounted` | Saldo de Essência, talentos adquiridos e `meta_unlocks`. |
| `PermanentProgressionService` | `game/progression/permanent_progression_service.gd` | `Node` | Compras na árvore, validação de pré-requisitos, Respec e aplicação única por run. |
| `SaveService` | `game/progression/save_service.gd` | `RefCounted` | Persistência em `user://progression_save.json` com escrita atômica (`.tmp`), backup (`.bak`) e validação de schema. |

---

## 4. Catálogo do Vertical Slice (Guerreiro)

### Evoluções de Partida (`content/progression/upgrades/`)
- **Transformações Exclusivas (`warrior_strike_primary_form`):**
  - `trans_meia_lua.tres`: substitui a Estocada por arco frontal de 180° (até 6 alvos, +15% dano). Exclui `trans_perfuracao`.
  - `trans_perfuracao.tres`: substitui a Estocada por investida linear perfurante de 4.4m (até 8 alvos em linha, +25% dano). Exclui `trans_meia_lua`.
- **Transformação Secundária (`warrior_strike_secondary_form`):**
  - `trans_giro.tres`: evolui a Meia-lua para Giro 360° (requer `trans_meia_lua` + desbloqueio permanente `unlock_spin`).
- **Melhorias de Atributos e Habilidade:**
  - `stat_dano.tres`: +22% Dano (até 5 ranks).
  - `stat_velocidade_ataque.tres`: +18% Velocidade de Ataque (até 5 ranks).
  - `stat_vida_maxima.tres`: +25 Vida Máxima (até 4 ranks).
  - `ability_alcance.tres`: +18% Alcance/Área e +1 alvo máximo (até 3 ranks).
- **Modificadores Especiais:**
  - `mod_fogo.tres`: aplica Queimadura (DoT por 3s + VFX de fogo).
  - `mod_eco.tres`: gera um eco espiritual 0.20s após o golpe principal (`allow_secondary_triggers = false` impede que o eco gere outro eco).

### Árvore Permanente de Talentos (6 Nós Ramificados)
1. `talent_vitality_root` (**Sangue Ancestral** — Atributo, 3 ranks): +20 Vida Máxima inicial.
2. `talent_warrior_might` (**Fúria do Guerreiro** — Atributo exclusivo `warrior`, 3 ranks): +15% Dano base para o Guerreiro.
3. `talent_swift_reflexes` (**Reflexos Ágeis** — Atributo, 2 ranks): +10% Velocidade de Ataque e +6% Velocidade de Movimento.
4. `talent_unlock_whirlwind` (**Segredo do Redemoinho** — Desbloqueio): habilita `trans_giro` (Giro 360°) nas partidas.
5. `talent_pyromancy_spec` (**Afinidade das Cinzas** — Especialização): dobra o peso de `mod_fogo` nas ofertas e aumenta o DPS da Queimadura em +35%.
6. `talent_veteran_herald` (**Herança do Veterano** — Modificador de Partida): inicia toda partida com +12 XP (garantindo uma escolha de evolução imediata na Wave 1).
