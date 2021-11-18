# Simulador Sistema Hidráulico da Paraíba do Sul

## Introdução

Este projeto tem como desenvolver um simulador da operação do Sistema Hidráulico da Paraíba do Sul fiel a regularmentações e restrições especiais definidas pela Agência Nacional de Águas **(to do: adicionar ref a resoluções)**, que comunmente não podem ser modeladas propriamente em programas mais gerais. A aplicação desse simulador permitirá experimentação e validação com respeito a possíveis novas políticas e estratégias de despacho que visem otimizar este sistema específico.

## Identificação de plantas

O Sistema Hidráulico da Paraíba do Sul e suas periferias possuem usinas de interesse bem definidas. Neste simulador, as usinas consideradas serão constantemente identificadas por uma `String` particular, que deverão ser respeitadas a todo momento como código de identificação. Tais usinas e seus respectivos códigos são:
* Fontes A: `fontes_a`
* Fontes BC: `fontes_bc`
* Funil: `funil`
* Ilha dos Pombos: `ilha_dos_pombos`
* Jaguari: `jaguari`
* Lajes: `lajes`
* Nilo Peçanha: `nilo_pecanha`
* Paraibuna: `paraibuna`
* Pereira Passos: `pereira_passos`
* Picada: `picada`
* Santana: `santana`
* Simplício: `simplicio`
* Sobragi: `sobragi`
* Santa Branca: `sta_branca`
* Santa Cecília: `sta_cecilia`
* Tocos: `tocos`
* Vigário: `vigario`

**O simulador foi programado sob uma modelagem que considera as usinas acima, e as usinas acima somente. Ausência de dados de entrada referente a qualquer uma delas, ou uso incorreto dos indentificadores, poderá acarretar no não funcionamento do simulador, a menos que seja especificado o contrário.**

## Arquivos de Referência

O simulador foi desenvolvido utilizando como referência projetos do mesmo sistema modelados em dois programas independentes: SUISHI e SDDP. Os arquivos de tais projetos podem ser encontrados respectivamente nas pastas `SUISHI` e `1_PMO_Agosto_ONS_Paraiba_Sul_suishi_2017`. O simulador, apesar de usar seus dados como base, não utiliza diretamente os arquivos destas pastas, eles foram incluídos somente com fins de referência.

## Dados de entrada

Em seguida, serão explicadas pastas que contém dados que são utilizados como entrada para o simulador e seus respectivos conteúdos. A princípio, todos os dados estão localizados no diretório `input_data`, porém esse nome pode ser alterado e passado como argumento quando a simulação for executada. **Enfatiza-se a importância de que arquivos CSV da mesma natureza respeitem mutuamente suas dimensões, especialmente se tal eixo representa uma grandeza temporal.** Por exemplo, os arquivos da pasta `flow_data` devem conter o mesmo número de linhas, ou seja, todas as usinas devem ter o mesmo número de anos de vazão natural histórica.
* `evaporation_data`
  * `coefficients`: contém arquivos CSV com uma coluna contendo os coeficientes de evaporação de cada mês (ordenado de 1 a 12) em `mm/Mês`. Se o arquivo para uma planta espefícica estiver ausente, seus valores serão considerados zero.
  * `polynomials`: Para algumas usinas com reservatório, é pertinente considerar sua área no momento de calcular sua evaporação. Para tal, os coeficientes dos polinômios Volume X Cota e Cota X Área são providos, para cada planta, na forma de um arquivo CSV com os coeficientes dispostos respectivamente na primeira e segunda linha, em ordem crescente de expoente da esquerda para a direita. Caso o arquivo para uma usina específica esteja ausente, sua área será considerada constante de acordo com o informado no arquivo `hidroplants_params.csv`. O polinômio deve considerar volume em `Hm^3`, cota em `m`, e Área em `Km^2`.
* `flow_data`: dados históricos de vazão natural para serem utilizados na simulação de maneira determinística. Dados estão dispostos, para cada usina, em um arquivo CSV com colunas correspondendo a meses (ordenado de 1 a 12) e linhas a anos (ordem crescente), em `m^3/s`. **Deve ser fornecido um arquivo para cada planta, mesmo que este seja nulo.**
* `generation_data`: os arquivos CSV nessa pasta seguem precisamente o modelo de arquivo de saída do SUISHI. Apesar dos arquivos estarem completos por fins de simplicidade, apenas as colunas `QTUR` (vazão turbinada em `m^3/s`), `VOLF` (volume final em `Hm^3`) e `GHID` (geração em `MW`) são consideradas na prática.
* `irrigation_data`: arquivos CSV contendo dados referentes ao uso consuntivo para cada usina, dispostos para cada mês em uma linha (ordenado de 1 a 12) em `m^3/s`. Caso o arquivo esteja ausente, os valores para usina serão considerados zero.

Outros arquivos com dados de entrada na pasta `input_data` são `hidroplants_params.csv` e `topology.csv`.

O arquivo `hidroplants_params.csv` contém parâmetros gerais de todas usinas, estes são:
* `max_spillage`: vertimento máximo, em `m^3/s`.
* `min_spillage`: vertimento mínimo, em `m^3/s`.
* `max_turbining`: turbinamento máximo, em `m^3/s`.
* `min_turbining`: turbinamento mínimo, em `m^3/s`.
* `max_reservoir`: reservatório máximo, em `Hm^3`.
* `min_reservoir`: reservatório mínimo útil, em `Hm^3`.
* `min_reservoir_ope`: volume operacional mínimo, de 0 a 1 (0 a 100%).
* `turbines_to`: usina para qual turbina.
* `spills_to`: usina para qual verte.
* `generation_coef`: coeficiente médio de geração, em `MW/m^3/s` (será negativo caso a usina seja de bombeamento).
* `area`: área do reservatório, em `km^2`.
* `IH`: índice histórico, de 0 a 1 (0 a 100%).
* `volume_start`: volume inicial do reservatório, em `Hm^3`.

Para fins práticos, medidas sem limite mínimo são definidas como zero, e sem limite máximo como 99999.

Já o arquivo `topology.csv` determina uma usina e quem está a sua jusante, por `plant` e `downstream`, respectivamente.

## Metodologia

Em um primeiro momento na simulação, as vazões incrementais determinísticas de todas as usinas são calculadas substraindo-se a vazão natural de sua planta a montante de sua própria. Isto já é realizado para todo o domínio temporal da simulação, uma vez que estes valores são pré determinados.

Para cada usina, é calculada sua afuência de maneira:

$$
Af = Q_{inc}+V_{mont}+T_{mont}-Ev-C
$$
Onde:
* `Af`: Afluência.
* `Qinc`: Vazão incremental.
* `Vmont`: Vertimento da usina a montante, caso esta exista.
* `Tmont`: Turbinamento da usina a montante, caso esta exista.
* `Ev`: Evaporação, calculada da maneira que foi explicitada na sessão de "Arquivos de entrada".
* `C`: Uso consuntivo, pré determinado.

O valor vertido e turbinado dependerão das condições do sistema, apesar do comportamento básico de uma usina com reservatório no simulador ser sempre turbinar o valor mínimo estabelecido. Em geral, vertimento ocorre apenas quando o sistema precisa liberar mais volume do que o normal, mas o máximo de turbinamento já foi atingido. Caso o reservatório esteja em seu mínimo útil, será liberado apenas o novo volume afluente. Já caso esteja em seu máximo, maior volume será liberado para evitar enchentes. Desta maneira, o reservatório é atualizado de forma que:

$$
R(t) = R(t-1)+Af-V-T
$$

Onde:
* `R`: É o volume do reservatório.
* `Af`: Afluência.
* `V`: Vertimento.
* `T`: Turbinamento.

Uma usina fio d'agua respeita essencialmente as mesmas regras acima. Porém, uma vez que seu reservatório é inflexível, deverá ser verdade que:

$$
T+V=Af
$$

Em cada passo da simulação, o programa simula a operação de cada uma das usinas "de cima para baixo", isto é, começando pelas usinas mais a montante, para que a afluência das usinas ajusantes possam ser calculadas de acordo.