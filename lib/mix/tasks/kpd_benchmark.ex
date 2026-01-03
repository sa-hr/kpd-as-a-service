defmodule Mix.Tasks.Kpd.Benchmark do
  @moduledoc """
  Mix task to benchmark API endpoint performance.

  Measures and prints the duration of each API call between request start
  and response received for all endpoints.

  ## Usage

      mix kpd.benchmark

  ## Options

    * `--iterations` - Number of iterations per endpoint (default: 10)
    * `--warmup` - Number of warmup iterations (default: 2)
    * `--verbose` - Show log output during benchmark (default: false)

  ## Examples

      mix kpd.benchmark
      mix kpd.benchmark --iterations 50
      mix kpd.benchmark --iterations 100 --warmup 5

  """

  use Mix.Task

  import Plug.Test

  require Logger

  alias KPD.Api.Router

  @shortdoc "Benchmarks API endpoint performance"

  @switches [
    iterations: :integer,
    warmup: :integer,
    verbose: :boolean
  ]

  @aliases [
    i: :iterations,
    w: :warmup,
    v: :verbose
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, switches: @switches, aliases: @aliases)

    iterations = Keyword.get(opts, :iterations, 10)
    warmup = Keyword.get(opts, :warmup, 2)
    verbose = Keyword.get(opts, :verbose, false)

    # Start only the required services (not the web server)
    Application.ensure_all_started(:telemetry)
    Application.ensure_all_started(:ecto_sql)
    {:ok, _} = KPD.Repo.start_link()

    # Suppress logging during benchmark unless verbose
    if !verbose do
      Logger.configure(level: :warning)
    end

    router_opts = Router.init([])

    Mix.shell().info("KPD API Performance Benchmark")
    Mix.shell().info("==============================")
    Mix.shell().info("Iterations: #{iterations}, Warmup: #{warmup}\n")

    # Get test data for realistic queries
    test_data = gather_test_data(router_opts)

    endpoints = build_endpoints(test_data)

    results =
      Enum.map(endpoints, fn {name, method, path} ->
        # Warmup
        for _ <- 1..warmup do
          make_request(method, path, router_opts)
        end

        # Benchmark
        times =
          for _ <- 1..iterations do
            {time, _response} = :timer.tc(fn -> make_request(method, path, router_opts) end)
            time
          end

        stats = calculate_stats(times)
        {name, path, stats}
      end)

    # Print results
    print_results(results)
  end

  defp gather_test_data(router_opts) do
    # Get a root code for hierarchy tests
    %{"data" => [%{"code" => root_code} | _]} =
      make_request(:get, "/api/product_classes/roots?limit=1", router_opts)
      |> Map.get(:resp_body)
      |> JSON.decode!()

    # Get a level 3 code for deeper hierarchy tests
    %{"data" => [%{"code" => level3_code} | _]} =
      make_request(:get, "/api/product_classes?level=3&limit=1", router_opts)
      |> Map.get(:resp_body)
      |> JSON.decode!()

    %{
      root_code: root_code,
      level3_code: level3_code
    }
  end

  defp build_endpoints(test_data) do
    [
      # System endpoints
      {"Health Check", :get, "/api/health"},
      {"Statistics", :get, "/api/stats"},
      {"OpenAPI Spec", :get, "/api/openapi.yaml"},

      # Listing endpoints
      {"List Product Classes (default)", :get, "/api/product_classes"},
      {"List Product Classes (level 1)", :get, "/api/product_classes?level=1"},
      {"List Product Classes (limit 50)", :get, "/api/product_classes?limit=50"},
      {"List Roots", :get, "/api/product_classes/roots"},

      # Search endpoints
      {"Search by Name (Croatian)", :get, "/api/product_classes/search?q=poljoprivreda"},
      {"Search by Name (English)", :get, "/api/product_classes/search?q=agriculture&lang=en"},
      {"Search by Name (limit 50)", :get, "/api/product_classes/search?q=proizvod&limit=50"},
      {"Search by Code Prefix", :get, "/api/product_classes/search_by_code?code=A01"},

      # Single item endpoints
      {"Get by Code", :get, "/api/product_classes/by_code/#{test_data.root_code}"},

      # Hierarchy endpoints
      {"Get Children", :get, "/api/product_classes/by_code/#{test_data.root_code}/children"},
      {"Get Descendants", :get,
       "/api/product_classes/by_code/#{test_data.root_code}/descendants"},
      {"Get Ancestors", :get, "/api/product_classes/by_code/#{test_data.level3_code}/ancestors"},
      {"Get Full Path", :get, "/api/product_classes/by_code/#{test_data.level3_code}/full_path"},
      {"Get Parent", :get, "/api/product_classes/by_code/#{test_data.level3_code}/parent"}
    ]
  end

  defp make_request(method, path, router_opts) do
    conn(method, path)
    |> Router.call(router_opts)
  end

  defp calculate_stats(times) do
    sorted = Enum.sort(times)
    count = length(times)

    min = List.first(sorted)
    max = List.last(sorted)
    sum = Enum.sum(times)
    avg = sum / count

    # Median
    median =
      if rem(count, 2) == 0 do
        mid = div(count, 2)
        (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
      else
        Enum.at(sorted, div(count, 2))
      end

    # P95 and P99
    p95_idx = floor(count * 0.95)
    p99_idx = floor(count * 0.99)
    p95 = Enum.at(sorted, min(p95_idx, count - 1))
    p99 = Enum.at(sorted, min(p99_idx, count - 1))

    # Standard deviation
    variance = Enum.reduce(times, 0, fn t, acc -> acc + :math.pow(t - avg, 2) end) / count
    std_dev = :math.sqrt(variance)

    %{
      min: min,
      max: max,
      avg: avg,
      median: median,
      p95: p95,
      p99: p99,
      std_dev: std_dev
    }
  end

  defp print_results(results) do
    # Header
    Mix.shell().info(
      String.pad_trailing("Endpoint", 35) <>
        String.pad_leading("Min", 10) <>
        String.pad_leading("Avg", 10) <>
        String.pad_leading("Median", 10) <>
        String.pad_leading("P95", 10) <>
        String.pad_leading("P99", 10) <>
        String.pad_leading("Max", 10) <>
        String.pad_leading("StdDev", 10)
    )

    Mix.shell().info(String.duplicate("-", 105))

    # Results
    Enum.each(results, fn {name, _path, stats} ->
      Mix.shell().info(
        String.pad_trailing(name, 35) <>
          format_time(stats.min) <>
          format_time(stats.avg) <>
          format_time(stats.median) <>
          format_time(stats.p95) <>
          format_time(stats.p99) <>
          format_time(stats.max) <>
          format_time(stats.std_dev)
      )
    end)

    Mix.shell().info(String.duplicate("-", 105))

    # Summary
    all_avgs = Enum.map(results, fn {_, _, stats} -> stats.avg end)
    total_avg = Enum.sum(all_avgs)
    slowest = Enum.max_by(results, fn {_, _, stats} -> stats.avg end)
    fastest = Enum.min_by(results, fn {_, _, stats} -> stats.avg end)

    Mix.shell().info("\nSummary:")
    Mix.shell().info("  Total endpoints: #{length(results)}")
    Mix.shell().info("  Sum of averages: #{format_time_value(total_avg)}")

    {fastest_name, _, fastest_stats} = fastest
    Mix.shell().info("  Fastest: #{fastest_name} (#{format_time_value(fastest_stats.avg)} avg)")

    {slowest_name, _, slowest_stats} = slowest
    Mix.shell().info("  Slowest: #{slowest_name} (#{format_time_value(slowest_stats.avg)} avg)")
  end

  defp format_time(microseconds) do
    String.pad_leading(format_time_value(microseconds), 10)
  end

  defp format_time_value(microseconds) when microseconds >= 1000 do
    "#{Float.round(microseconds / 1000, 2)}ms"
  end

  defp format_time_value(microseconds) do
    "#{round(microseconds)}µs"
  end
end
