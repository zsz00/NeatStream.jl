@testset "FilterOperator" begin

    df = DataFrame(x = [1, 2, 3, 4, 5, 6], y = [6, 5, 4, 3, 2, 1], z = [6, 5, 4, 3, 2, 1])
    conn_df = NeatStream.TablesConnector(df);
    stream = NeatStream.BatchStream(conn_df; batch_size = 2);

    filter = NeatStream.FilterOperator([:x, :y])
    push!(stream, filter)

    stream_filtered = NeatStream.listen(stream)

    @test (:x in propertynames(stream_filtered)) == true
    @test (:y in propertynames(stream_filtered)) == true
    @test (:z in propertynames(stream_filtered)) == false

    filter = NeatStream.FilterOperator(:x)
    push!(stream, filter)

    stream_filtered = NeatStream.listen(stream)

    @test (:x in propertynames(stream_filtered)) == true
    @test (:y in propertynames(stream_filtered)) == false
    @test (:z in propertynames(stream_filtered)) == false

    @test_logs (:warn, "There are duplicate columns.") NeatStream.FilterOperator([:x, :x, :y])
    @test_logs (:warn, "There are duplicate columns.") NeatStream.FilterOperator(:x, :x, :y)
end
