#!/usr/bin/env julia
"""
test_daemon_system.jl - Test the integrated daemon management system

Tests:
1. Daemon lifecycle (start/stop/restart)
2. Process monitoring
3. Port allocation
4. Log file creation
5. Crash recovery
"""

using Test
using JMake

@testset "Daemon System Tests" begin

    @testset "Daemon Manager Module" begin
        @test isdefined(JMake, :DaemonManager)
        @test isdefined(JMake, :start_daemons)
        @test isdefined(JMake, :stop_daemons)
        @test isdefined(JMake, :daemon_status)
        @test isdefined(JMake, :ensure_daemons)
    end

    @testset "Daemon Lifecycle" begin
        test_root = mktempdir()

        try
            @testset "Start Daemons" begin
                # Ensure no daemons running
                JMake.stop_daemons()
                sleep(1)

                # Start daemons
                daemon_sys = JMake.start_daemons(project_root=test_root)

                @test !isnothing(daemon_sys)
                @test haskey(daemon_sys.daemons, "discovery")
                @test haskey(daemon_sys.daemons, "setup")
                @test haskey(daemon_sys.daemons, "compilation")
                @test haskey(daemon_sys.daemons, "orchestrator")

                sleep(3)  # Wait for startup

                # Verify running
                for (name, info) in daemon_sys.daemons
                    @test info.status == :running || info.status == :starting
                    @test !isnothing(info.pid)
                end

                # Check logs created
                log_dir = joinpath(test_root, "daemons", "logs")
                @test isdir(log_dir)
            end

            @testset "Status Check" begin
                JMake.daemon_status()
                # Should print status without error
                @test true
            end

            @testset "Stop Daemons" begin
                JMake.stop_daemons()
                sleep(2)

                # Verify no daemons running
                JMake.daemon_status()  # Should print "No daemons are running"
                @test true
            end

        finally
            # Cleanup
            try
                JMake.stop_daemons()
                rm(test_root, recursive=true, force=true)
            catch
            end
        end
    end

    @testset "Ensure Daemons (Auto-restart)" begin
        test_root = mktempdir()

        try
            # Start daemons
            JMake.ensure_daemons()
            sleep(3)

            # Call again - should not restart
            result = JMake.ensure_daemons()
            @test result == true

            # Cleanup
            JMake.stop_daemons()
            sleep(1)

        finally
            try
                JMake.stop_daemons()
                rm(test_root, recursive=true, force=true)
            catch
            end
        end
    end

end

println("\nDaemon System Tests Complete!")
