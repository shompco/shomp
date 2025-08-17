defmodule Mix.Tasks.SyncStripeProducts do
  use Mix.Task

  @shortdoc "Syncs existing products with Stripe"
  def run(_) do
    # Start the application
    Mix.Task.run("app.start")

    IO.puts("Syncing products with Stripe...")
    
    case Shomp.Products.sync_all_products_with_stripe() do
      results when is_list(results) ->
        successful = Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)
        
        failed = length(results) - successful
        
        IO.puts("Sync completed:")
        IO.puts("  ✅ Successful: #{successful}")
        IO.puts("  ❌ Failed: #{failed}")
        
        if failed > 0 do
          IO.puts("\nFailed syncs:")
          results
          |> Enum.with_index()
          |> Enum.filter(fn {{:error, _}, _} -> true; _ -> false end)
          |> Enum.each(fn {{:error, reason}, index} ->
            IO.puts("  Product #{index + 1}: #{inspect(reason)}")
          end)
        end
        
      error ->
        IO.puts("Error syncing products: #{inspect(error)}")
    end
  end
end
