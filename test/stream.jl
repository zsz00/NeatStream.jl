@testset "Stream" begin
    @testset "AbstractStream" begin
        elements = 10
        df = DataFrame(x = [1:elements ...], y = [1:elements ...])
        conn = EasyStream.TablesConnector(df)
        stream = EasyStream.BatchStream(conn)
        qnt_loops = 0
        for data in stream
            qnt_loops = qnt_loops + 1
        end

        EasyStream.reset!(stream)

        qnt_loops_reset = 0
        for data in stream
            qnt_loops_reset = qnt_loops_reset + 1
        end

        @test qnt_loops == qnt_loops_reset
    end

    @testset "BatchStream" begin
        elements = 100
        df = DataFrame(x = [1:elements ...], y = [1:elements ...])
        conn = EasyStream.TablesConnector(df)

        batch_size = 10
        stream = EasyStream.BatchStream(conn, batch_size = batch_size)
        data = EasyStream.listen(stream)
        @test size(data)[1] == batch_size
        @test size(data)[2] == size(df)[2]

        elements = 5
        df = DataFrame(x = [1:elements ...], y = [1:elements ...])
        conn = EasyStream.TablesConnector(df)

        batch_size = 10
        stream = EasyStream.BatchStream(conn, batch_size = batch_size)
        data = EasyStream.listen(stream)
        @test size(data)[1] < batch_size
        @test size(data)[2] == size(df)[2]
        @test size(data)[1] == elements

        elements = 5
        df = DataFrame(x = [1:elements ...], y = [1:elements ...])
        conn = EasyStream.TablesConnector(df)

        stream = EasyStream.BatchStream(conn)
        i = 0
        for data in stream
            @test size(data)[1] == 1
            @test size(data)[2] == size(df)[2]
            i = i + 1
        end

        elements = 100
        df = DataFrame(x = [1:elements ...], y = [1:elements ...])
        conn = EasyStream.TablesConnector(df)

        batch_size = 100

        stream = EasyStream.BatchStream(conn, batch_size = batch_size)
        i = 0
        for data in stream
            @test size(data)[1] == batch_size
            @test size(data)[2] == size(df)[2]
            i = i + 1
        end

        @test i == Int(elements ./ batch_size)
    end

end
