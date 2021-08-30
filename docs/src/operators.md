# Operators

Durante o fluxo de dados, o desenvolvedor poderá manipular e processar os dados sob demanda. Neste interim, surge a ideia dos modificadores (__Operators__). O desenvolvedor poderá adicionar modificadores e eles irão manipular os dados após a função __listen__. Alguns exemplos de possibilidade:

- Geração de ruído
- Processamento de dados
- Filtragem de dados

## FilterOperator

O __FilterOperator__ é um __Operator__ com objetivo em filtrar colunas desnecessárias do _stream_. Exemplo de utilização:

```julia
NeatStream.reset!(stream_filter) # função para reiniciar o stream
operator_filter = NeatStream.FilterOperator(:y);
push!(stream_filter, operator_filter);

NeatStream.listen(stream_filter)
```

## AlterDataOperator

O __AlterDataOperator__ é um __Operator__ com objetivo em processar e alterar informações do _stream_. Ele recebe por parâmetro uma função que poderá manipular os dados, recebendo o dado e o evento do stream. Exemplo de utilização:

```julia
NeatStream.reset!(stream_filter) # função para reiniciar o stream
operator_alter_1 = NeatStream.AlterDataOperator((data,event)-> data[:x] .= 5)
push!(stream_filter, operator_alter_1);

NeatStream.listen(stream_filter)
```

O dado irá receber um _DataFrame_ e o evento será uma estrutura onde possuirá os argumentos de construção do __AbstractStream__ e do __AbstractConnector__. Desta forma, é possível alterar até a geração dos dados!
