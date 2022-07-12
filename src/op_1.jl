# 定义一个op
# 定义op的数据结构, 即op_state
struct Sum <: Operator
    init::Any
end

# 构造函数
function Sum(init::Any)
    return Sum(init)
end

# 功能实现
function apply!(sum::Sum, data::Any, event::Event)
    sum.init .+= data
    return nothing
end

