# Simulador Sistema Hidráulico da Paraíba do Sul

## Introdução

Este projeto tem como desenvolver um simulador da operação do Sistema Hidráulico da Paraíba do Sul fiel a regularmentações e restrições especiais definidas pela Agência Nacional de Águas, disponíveis [aqui](http://www.inea.rj.gov.br/ar-agua-e-solo/seguranca-hidrica/resolucoes-ana/), que comumente não podem ser modeladas propriamente em programas mais gerais. A aplicação desse simulador permitirá experimentação e validação com respeito a possíveis novas políticas e estratégias de despacho que visem otimizar este sistema específico.

## Identificação de Plantas

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

**O simulador foi programado sob uma modelagem que considera as somente usinas acima. Ausência de dados de entrada referente a qualquer uma delas, ou uso incorreto dos indentificadores, poderá acarretar no não funcionamento do simulador, a menos que seja especificado o contrário.**

## Arquivos de Referência

O simulador foi desenvolvido utilizando como referência projetos do mesmo sistema modelados em dois programas independentes: SUISHI e SDDP. Os arquivos de tais projetos podem ser encontrados respectivamente nas pastas `SUISHI` e `1_PMO_Agosto_ONS_Paraiba_Sul_suishi_2017`, dentro de `reference`. O simulador, apesar de usar seus dados como base, não utiliza diretamente os arquivos destas pastas, eles foram incluídos somente com fins de referência.

## Dados de Entrada

Em seguida, serão explicadas pastas que contém dados que são utilizados como entrada para o simulador e seus respectivos conteúdos. A princípio, todos os dados estão localizados no diretório `example`, porém esse nome pode ser alterado e passado como argumento quando a simulação for executada. **Enfatiza-se a importância de que arquivos CSV da mesma natureza respeitem mutuamente suas dimensões, especialmente se tal eixo representa uma grandeza temporal.** Por exemplo, os arquivos da pasta `flow_data` devem conter o mesmo número de linhas, ou seja, todas as usinas devem ter o mesmo número de anos de vazão natural histórica.
* `evaporation_data`
  * `coefficients`: contém arquivos CSV com uma coluna contendo os coeficientes de evaporação de cada mês (ordenado de 1 a 12) em `mm/Mês`. Se o arquivo para uma planta espefícica estiver ausente, seus valores serão considerados zero.
  * `polynomials`: Para algumas usinas com reservatório, é pertinente considerar sua área no momento de calcular sua evaporação. Para tal, os coeficientes dos polinômios Volume X Cota e Cota X Área são providos, para cada planta, na forma de um arquivo CSV com os coeficientes dispostos respectivamente na primeira e segunda linha, em ordem crescente de expoente da esquerda para a direita. Caso o arquivo para uma usina específica esteja ausente, sua área será considerada constante de acordo com o informado no arquivo `hidroplants_params.csv`. O polinômio deve considerar volume em `Hm^3`, cota em `m`, e Área em `Km^2`.
* `flow_data`: dados históricos de vazão natural para serem utilizados na simulação de maneira determinística. Dados estão dispostos, para cada usina, em um arquivo CSV com colunas correspondendo a meses (ordenado de 1 a 12) e linhas a anos (ordem crescente), em `m^3/s`. Caso o arquivo esteja ausente, os valores para usina serão considerados zero.
* `generation_data`: os arquivos CSV nessa pasta seguem o modelo de arquivo de saída do SUISHI, pois são, de fato, exatamente isso. Apesar dos arquivos estarem completos por fins de simplicidade, apenas as colunas `QTUR` (vazão turbinada em `m^3/s`), `VOLF` (volume final em `Hm^3`) e `GHID` (geração em `MW`) são consideradas na prática.
* `irrigation_data`: arquivos CSV contendo dados referentes ao uso consuntivo para cada usina, dispostos para cada mês em uma linha (ordenado de 1 a 12) em `m^3/s`. Caso o arquivo esteja ausente, os valores para usina serão considerados zero.
* `wait_data`: arquivos CSV contendo dados do volume de espera para cada usina, dispostos para cada mês em uma linha (ordenado de 1 a 12) em `Hm^3`. Caso o arquivo esteja ausente, será considerado sempre os volumes máximos.

Outros arquivos com dados de entrada na pasta `input_data` são `hidroplants_params.csv` e `topology.csv`.

O arquivo `hidroplants_params.csv` contém (e **deverá sempre conter**) parâmetros gerais de **todas usinas**, estes são:
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

### Operação Básica

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

O valor vertido e turbinado dependerão das condições do sistema, apesar do comportamento básico de uma usina com reservatório no simulador ser sempre turbinar o valor mínimo estabelecido. Em geral, vertimento ocorre apenas quando o sistema precisa liberar mais volume do que o normal, mas o máximo de turbinamento já foi atingido. Caso o reservatório esteja em seu mínimo operacional, será liberado apenas o novo volume afluente. Já caso esteja em seu máximo, maior volume será liberado para evitar enchentes. Desta maneira, o reservatório é atualizado de forma que:

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

Além das variáveis já mencionadas, é obviamente de grande interesse o cálculo do valor de geração de cada usina. Isso pode ser feito de diferentes maneiras, por exemplo, o SUISHI a calcula analiticamente considerando diversas variáveis. Por fins de simplicidade, optou-se por tomar um caminho mais simples, mas que ao mesmo tempo mimetiza o método completo do SUISHI. Isto foi feito considerando seus resultados de geração, e realizando uma regressão linear da mesma em função de seu volume e turbinamento. O resultado é, para cada usina, uma função que replica o metódo do SUISHI com precisão superior a 99%. Já para usinas sem reservatório, ou sem dados de geração disponíveis, é feito um cálculo diretamente pelo coeficiente médio de geração.

Em cada passo da simulação, o programa simula a operação de cada uma das usinas "de cima para baixo", isto é, começando pelas usinas mais a montante, para que a afluência das usinas ajusantes possam ser calculadas de acordo. Os estados finais do passo são, então, considerados como as condições iniciais do seguinte.

### Operação Especial do Sistema da Paraíba do Sul

O Sistema da Paraíba do Sul tem operação diferente da mencionada anteriormente, pois suas usinas devem ser capazes de se articular em conjunto para atender a determinadas restrições sob um acervo pré definido de regras, o que torna seu comportamento consideravelmente mais complexo do que os demais. As principais regras operativas especiais deste sistema estão disponíveis [aqui](http://www.inea.rj.gov.br/wp-content/uploads/2020/04/1382-2015.pdf), na Resolução Conjunta ANA/DAEE/IGAM/INEA nº 1.382, de 2015, que será explorada daqui em diante.

Vale atentar-se ao tópico I do Art. 1<sup>o</sup>, que define vazões mínimas. Para que sejam respeitadas tais vazões, mesmo que a usina em questão não possua reservatório ou afluência para tal, o simulador implementa um método recursivo que requisita volume extra para as plantas a montante, que atenderá ao pedido através de um incremento de afluência, dentro de seus limites operativos. O volume extra requisitado será exatamente o necessário para que a usina em déficit atinja seu mínimo estabelecido pela resolução.

Ao realizar o procedimento descrito no último parágrafo, os limites operativos mencionados respeitarão a risca os estágios de deplecionamento dispostos no item V do Art. 1<sup>o</sup>. Além dos três estágios oficiais apresentados, o simulador define um quarto estágio, que representa quando, não somente Funil, Santa Branca, e Jaguari já chegaram ao mínimo de seu terceiro estágio, como também é necessário  ativar o Art. 2<sup>o</sup>, que permite em casos extremos Paraibuna violar seu volume operacional mínimo em 425 Hm<sup>3</sup>.

Outro caso excepcional é o descrito no tópico IV c) do Art. 1<sup>o</sup>, isto é, quando o reservatório equivalente de Paraíba do Sul supera 80% de seu volume útil. Nesse caso, semelhante a quando há deplecionamento, Santa Cecília irá requisitar para as usinas a montante volume suficiente para alçancar sua defluência máxima. Tais usinas irão, então, liberar o que tiverem disponível para atender a solicitação.

Santa Cecília, por sua vez, irá gerenciar seu vertimento e turbinamento de acordo com os limites e prioridades definidos no tópico IV do Art. 1<sup>o</sup>.

## Execução

O simulador foi implementado inteiramente em Julia v1.6.3 em Windows 10 64-bit, portanto, tenha certeza de ter uma versão compatível instalada. Caso não tenha, seu download pode ser feito [aqui](https://julialang.org/downloads/). Durante a instalação, selecione a opção `add Julia to PATH`.

![rep_page](/figures/julia_page.png)

Caso o usuário possua mais domínio de Git, ele pode adquirir o programa realizando fork deste repositório. Caso contrário, uma alternativa é clicar em `code` e depois em `Download ZIP`, como indicado na figura:

![rep_page](/figures/rep_page.png)

Em seguida, extraia os arquivos da pasta compactada:

![rep_page](/figures/exp_page.png)

Para abrir o prompt de comando, clique em `Windows`+`R`, digite "cmd" na caixa que aparecer, e clique `Enter`.

![rep_page](/figures/run_page.png)

Após o prompt ser aberto, retorne para o explorador de arquivos e copie o caminho da pasta com os arquivos extraídos do programa:

![rep_page](/figures/path_page.png)

De volta no prompt, digite "cd", dê um espaço, e cole o caminho copiado teclando `Ctrl`+`V`, então, tecle `Enter`:

```
C:\> cd C:\simulatorParaibaDoSul.jl-master
```

Por fim, digite o comando abaixo e aperte `Enter` (tenha certeza que nenhum dos arquivos que será editado pelo programa esteja aberto, isto é, arquivos da pasta `results`):

```
julia --project run.jl "example"
```

Alternativamente, o parâmetro `"example"` poderá ser substituído por qualquer que seja o caminho para o diretório do projeto.

## Resultados

Executado o simulador com sucesso, seus resultados poderão ser encontrados na pasta `results`, e no sub diretório que terá o mesmo nome que foi dado ao caso, pelo argumento `case_name` de `run_simulation`. No caso pronto de exemplo, tal nome é `example`.

Nessa pasta, os resultados estarão agregados por variável em arquivos CSV. Estes arquivos terão como prefixo o valor de `case_name`, e seus sufixos indentificarão:
* `evaporation_m3_per_sec`: resultados de evaporação, em `m^3/s`.
* `generation_MW`: resultados de geração, em `MW`.
* `incremental_flow_m3_per_sec`: vazões incrementais, em `m^3/s`.
* `irrigation_m3_per_sec`: uso consuntivo, em `m^3/s`.
* `reservoir_Hm3`: resultados de reservatório, em `Hm^3`.
* `spillage_m3_per_sec`: resultados de vertimento, em `m^3/s`.
* `turbining_m3_per_sec`: resultados de turbinamento, em `m^3/s`.

Nos arquivos de resultado, além das variáveis específicas de cada arquivo, estão disponíveis as colunas:
* `step`: estágio da simulação.
* `month`: número do mês correspondente ao estágio.
* `stage`: estágio de deplecionamento do sistema, de 1 a 4.
* `ps_equivalent_reservoir`: reservatório útil equivalente do Sistema da Paraíba do Sul, de 0 a 1 (0 a 100%).
