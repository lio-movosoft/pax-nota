defmodule Nota.ImageListener do
  @moduledoc false
  use GenServer

  require Logger

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl true
  def init(_) do
    Phoenix.PubSub.subscribe(:masher_pubsub, "image_results")
    {:ok, nil}
  end

  @impl true
  def handle_info({:image_mashed, image_key, _variant_keys}, state) do
    Logger.info("Image processed: #{image_key}")
    Nota.Uploads.update_processing_status_by_key(image_key, :completed)
    Phoenix.PubSub.broadcast(Nota.PubSub, "image:#{image_key}", :image_processed)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warning("ImageListener unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
end
