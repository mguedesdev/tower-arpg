# Direção de arte — Pátio Arcano (v0.3)

**Referência principal:** `docs/reference/patio_arcano_referencia.png` (imagem enviada pelo criador).

## Visão

Jogo 3D de câmera isométrica, low poly estilizado, com aparência de **diorama de fantasia**. A simplicidade da geometria deve deixar o combate e as decisões de build legíveis. O jogo deve parecer acabado pela composição, não pela quantidade de polígonos.

**Palavras-guia:** miniatura, legível, elegante, arcano, limpo, responsivo.

## Elementos obrigatórios

1. **Câmera:** projeção ortográfica ou perspectiva muito leve; orientação diagonal consistente. Evitar mudanças bruscas de ângulo em combate. Zoom deve preservar leitura no PC e mobile.
2. **Arena modular:** placas de pedra quadradas com juntas estreitas; pequenas variações de tom. O chão é discreto para servir de tela aos ataques e inimigos.
3. **Formas grandes:** colunas, ruínas, bancos, pedestais, cristais; silhuetas reconhecíveis vistas de longe. Evitar detalhes minúsculos.
4. **Foco visual:** jogador com contraste do fundo, ataques com bordas e cores claras, efeitos limitados por prioridade.
5. **Iluminação:** sombras macias de uma direção dominante + preenchimento. Materiais predominantemente foscos, sem excesso de brilho.
6. **HUD:** painéis escuros compactos, rótulos claros, dourado para detalhes não urgentes, cor de perigo para dano/alerta. Suporte a controle touch no futuro.

## Paleta inicial

Cores **aproximadas e ajustáveis**, escolhidas com a referência visual. Não são uma especificação de cor imutável.

| Papel | Hex aproximado | Uso |
|---|---|---|
| Piso médio | `#51566F` | placas de pedra |
| Piso alternativo | `#565A75` | variação de tiles |
| Juntas/sombra | `#22293B` | divisão entre peças |
| Pedra de prop | `#555E85` | pilares, ruínas |
| Roxo arcano | `#B355E8` | cristais, efeitos mágicos |
| Ouro quente | `#F6AE57` | runas, bordas, recompensa |
| UI carvão | `#14161F` | painéis da interface |
| Texto principal | `#F8E9CD` | títulos |

As classes têm cores de identidade próprias, mas cada ataque deve se distinguir por **forma, movimento e timing**, não apenas por cor.

## Personagens

- Proporções levemente caricatas; cabeça e braços expressivos; corpo legível em escala pequena.
- Visual modular em *composição* (braços, pernas, armadura, arma), mas itens comuns **não mudam aparência** no MVP.
- Guerreiro: silhueta sólida, arma claramente identificável, golpe exagerado para leitura isométrica.
- Mago: chapéu/cajado ou outro traço característico; volumes longos e claros.
- Arqueiro: arco e quiver definindo a silhueta.
- Evitar detalhes de tecido/metal que desaparecem quando a câmera se afasta.

## Inimigos, habilidades e VFX

- Um inimigo comum precisa ser reconhecido pela silhueta, mesmo com efeitos na tela.
- Diferenciar projéteis, golpes em arco e área circular por geometria e ritmo.
- VFX fortes nos instantes importantes (acerto, evolução, morte de elite), contidos durante ataques repetidos.
- Priorizar a leitura de ameaças reais e a área segura para deslocamento.
- Definir limites para VFX por tela e testar mobile antes de elevar a contagem de inimigos.

## Arena — primeiro cenário

- Piso quadrado de 52×52 unidades, repetindo placas grandes, com círculo dourado de spawn.
- Pedestais, colunas e cristais nas regiões externas.
- Zona central mais limpa para testar combate; props decorativos não têm colisão nesta versão.
- Design de *tower floor*: arena visual independente do WaveManager.
- A câmera acompanha o jogador; o cenário não precisa de carregamento dinâmico no MVP.

## Interface — primeiro protótipo

- Painel superior esquerdo com nome da arena e subtítulo pequeno.
- Status de wave, vida, ataque e abates abaixo em tamanho reduzido.
- Instruções de WASD e teclas de forma na parte inferior esquerda.
- Mensagens de progresso/morte próximas à parte inferior, sem competir com combate.

## Restrições artísticas e técnicas

- Preservar FPS e legibilidade em tela pequena; não confundir *low poly* com cubos sem composição.
- Evitar transparências grandes, iluminação volumétrica pesada e sombras desnecessárias em cada inimigo comum.
- Modelar assets reutilizáveis em Blender; exportação GLB validada antes de declarar o pipeline pronto.
- As dimensões, cores e câmera são parâmetros de partida — devem ser ajustadas após testes com o guerreiro e efeitos reais.

## Checklist de aprovação visual

- [ ] Vista isométrica reconhecível e confortável.
- [ ] Jogador distinguível do cenário e inimigos.
- [ ] Piso e props no mesmo estilo.
- [ ] Cada forma de golpe visualmente distinta.
- [ ] HUD compreensível sem esconder ataques.
- [ ] Visual legível em resolução mobile de referência.
- [ ] 60 FPS no PC de desenvolvimento sem inimigos como baseline, a medir.
