# Data Stream

Um fluxo de dados (_data stream_) é uma sequência ordenada, podendo ser ilimitada, de dados que chegam ao longo do tempo. Os intervalos de tempo entre a chegada de cada item podem variar. Os dados podem ser um atributo simples, como tuplas de banco de dados relacional ou estruturas mais complexas, como imagens [Krawczyk et al, 2017].

A ideia será escutar o stream por um certo período de tempo. Ficando na seguinte forma:

```julia
NeatStream.listen(stream, time = 1000)
```

Contudo, nessa primeira versão os dados estão em memória. Não necessitando por enquanto o tempo. Essa característica de fluxo de dados apresenta a necessidade de desenvolver sequenciamento em lote, não importando o tempo de escuta.
Desta forma, podemos ter diversos tipos de Stream e todos irão herdar:

```julia
AbstractStream
```

A maior dificuldade é na parte na captura de dados pois pode variar. Alguns exemplos: CSV, API, memória, geração de dados, ... Para tal, foi imaginado um tipo genérico chamado __Connector__ que será explorado na próxima seção.

## Connectors

O __Connector__ será responsável em capturar os dados na fonte e irá passar para o _stream_ já processado. O _stream_ possuirá um __AbstractConnector__ e ele precisará possuir algumas funções implementadas e a principal é __next__ que irá fornecer o próximo dado processado. Foi implementado dois __Connectors__:

- __GeneratorConnector__: um conector para geração de dados.
- __TablesConnector__: um conector para dados que respeitam a interface Tables.jl

### GeneratorConnector

O __GeneratorConnector__ tem como objetivo utilizar funções para gerar dados. A ideia é que ele possa ser utilizado com o SyntheticDatasets.jl. O construtor precisará receber a função geradora e poderá ser passado os argumentos adicionais dessa função como parâmetro

```julia
using NeatStream
using SyntheticDatasets

conn_gen = NeatStream.GeneratorConnector(SyntheticDatasets.generate_blobs, 
						centers = [-1 1;-0.5 0.75], 
                                        	cluster_std = 0.225, 
                                        	center_box = (-1.5, 1.5));
```

O DataFrames implementa a interface [Tables.jl](https://github.com/JuliaData/Tables.jl), mas existem outros pacotes como:
- CSV
- MLJ
- SQLite

Exemplo:

```julia
using DataFrames
df = DataFrames.DataFrame(x = [1, 2, 3, 4, 5, 6], y = [6, 5, 4, 3, 2, 1]);
```

Para criar um __TablesConnector__ é só passar o dado diretamente para ele.

```julia
conn_df = NeatStream.TablesConnector(df);
```

Existem outras funções auxiliaries como:

```julia
conn_df_suffle = NeatStream.TablesConnector(df, shuffle = true); # Suffle
conn_df_orderby = NeatStream.TablesConnector(df, :x); # Ordernação
```

## Streams

### BatchStream

Foi implementado o __BatchStream__, que é um __AbstractStream__, e ele abstrai o fluxo de dados. Ele receberá por parâmetro um __AbstractConnector__ e opcionalmente o tamanho do _batch_. Exemplo:

```julia
stream = NeatStream.BatchStream(conn_gen; batch_size = 5);
```

Ou fazer uma interação através de um _for_.

```julia
for values in stream
	@show values
	break # é um loop infinito pois utiliza um gerador de dados
end
```
Dependendo do caso, o _stream_ pode possuir um tamanho infinito e, assim, foi criado a função __range__ para auxiliar definindo um limite na interação.

```julia
for values in NeatStream.range(5, stream)
	NeatStream.listen(stream)
end
```

## Referências
Krawczyk, Bartosz, et al. 'Ensemble learning for data stream analysis: A survey.' Information Fusion 37 (2017): 132-156.