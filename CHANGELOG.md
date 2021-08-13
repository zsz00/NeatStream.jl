v0.1.0   2021.8.13
base on EasyStream.jl 
学习

v0.2.0 2021.8.15
1. table 的 stream. 




TODO

1. 集成Chain.jl
2. 集成 DataFrames.jl, Transducers.jl, OnlineStats.jl 
3. 集成Dagger.jl
4. 加 ops


-------------------------------------------------------------------------
重设计:
stream

op(stat,data) -> nothing


代码生成: op_1(stat), 会自己生成 一个 struct对象.  




