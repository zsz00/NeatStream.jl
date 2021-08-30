v0.0.1   2021.8.13
base on EasyStream.jl 
learn, update 

v0.0.2 2021.8.14
1. 修改变量名, 加注释. 
2. 加入op到op_1.jl中
3. 扩展 connectors

v0.0.3 2021.8.15
1. 基于flink 重写api

v0.0.5 2021.8.30
基础功能实现




TODO
1. 集成Chain.jl
2. 集成 DataFrames.jl, Transducers.jl, OnlineStats.jl 
3. 集成Dagger.jl
4. 加 ops


-------------------------------------------------------------------------
重设计:
参考 Transducers.jl, OnlineStats.jl, DataTools.jl, chain.jl, streamz, flink 因为要兼容. 

应该是 每个op 有自定义的state. stream上也可以有内置的state 
op(stat,data) -> stat,data
数据和状态都要 在ops 之间传输 

ops之间可以用queue吗? 可以


1. 设计 api, 参考的flink 
2. 实现流处理, 参考的streamz
3. 执行优化,并行. 难点

env -> datastream -> op -> func -> output


执行在  processElement(op, input) -> output

数据怎么 流进去的, 什么逐个op执行的 ??


clint --> server 
julia/python --> flink server ?? 不行


