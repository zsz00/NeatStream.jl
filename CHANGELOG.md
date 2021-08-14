v0.1.0   2021.8.13
base on EasyStream.jl 
学习

v0.2.0 2021.8.15
1. 修改变量名, 加注释. 
2. 加入op到op_1.jl中
3. 扩展 connectors



TODO

1. 集成Chain.jl
2. 集成 DataFrames.jl, Transducers.jl, OnlineStats.jl 
3. 集成Dagger.jl
4. 加 ops


-------------------------------------------------------------------------
重设计:
参考 Transducers.jl, OnlineStats.jl, DataTools.jl, chain.jl, streamz, flink 因为要兼容. 

应该是 每个op 有自定义的state. stream上也可以有内置的state 

stream

op(stat,data) -> stat,data
数据和状态都要 在ops 之间传输 




1. 设计 api, 参考的flink 
2. 实现流处理

env -> datastream -> op -> output



