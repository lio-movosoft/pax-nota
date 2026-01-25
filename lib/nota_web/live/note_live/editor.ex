defmodule NotaWeb.NoteLive.Editor do
  @moduledoc """
  Bear-like markdown editor LiveView.

  Key behaviors:
  - Parses body to Document on mount
  - Tracks focused block via cursor events from JS
  - Only re-renders when content changes, not cursor movement
  - Uses `phx-update="ignore"` on focused block to prevent input interference
  """
  use NotaWeb, :live_view

  alias Nota.Notes
  alias Nota.Notes.Markdown.{Document, Parser}
  alias Nota.Uploads

  import NotaWeb.MarkdownComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        <form phx-change="update_title" phx-submit="update_title" class="flex-1">
          <textarea
            name="title"
            phx-debounce="300"
            phx-blur="blur_title"
            rows="1"
            class="block w-full resize-none border-0 bg-transparent text-xl font-semibold p-0 focus:outline-none focus:ring-0 focus:bg-base-100 rounded"
            style="field-sizing: content;"
            placeholder="Untitled"
          ><%= @title %></textarea>
        </form>
        <:subtitle>
          {Calendar.strftime(@note.updated_at, "%Y/%m/%d")} - last edit <br />
          {Calendar.strftime(@note.inserted_at, "%Y/%m/%d")} - creation
        </:subtitle>
        <:actions>
          <.button navigate={~p"/notes"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button navigate={~p"/notes/#{@note}/images"}>
            <.icon name="hero-photo" />
          </.button>
          <.button :if={@dirty} variant="primary" phx-click="save">
            <.icon name="hero-check" /> Save
          </.button>
          <span :if={!@dirty} class="text-sm text-base-content/50">Saved</span>
        </:actions>
      </.header>

      <.modal
        :if={@live_action == :images}
        id="images-modal"
        show
        on_cancel={JS.patch(~p"/notes/#{@note}")}
      >
        <.header>
          Images
          <:subtitle>Upload up to {@max_images} images. Select one as cover.</:subtitle>
        </.header>

        <div class="mt-6 space-y-6">
          <div :if={@can_upload} class="card bg-base-200 p-6">
            <h3 class="font-semibold mb-4">Upload New Image</h3>
            <form
              id="upload-form"
              phx-submit="upload_save"
              phx-change="upload_validate"
              class="space-y-4"
            >
              <div class="flex flex-col gap-4">
                <.live_file_input
                  upload={@uploads.image}
                  class="file-input file-input-bordered w-full"
                />

                <div :for={entry <- @uploads.image.entries} class="flex items-center gap-4">
                  <.live_img_preview entry={entry} class="w-24 h-24 object-cover rounded" />
                  <div class="flex-1">
                    <div class="text-sm font-medium">{entry.client_name}</div>
                    <progress
                      class="progress progress-primary w-full"
                      value={entry.progress}
                      max="100"
                    >
                      {entry.progress}%
                    </progress>
                    <div :for={err <- upload_errors(@uploads.image, entry)} class="text-error text-sm">
                      {error_to_string(err)}
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    class="btn btn-ghost btn-sm"
                  >
                    <.icon name="hero-x-mark" class="size-4" />
                  </button>
                </div>

                <div :for={err <- upload_errors(@uploads.image)} class="text-error text-sm">
                  {error_to_string(err)}
                </div>

                <button
                  type="submit"
                  class="btn btn-primary w-fit"
                  disabled={@uploads.image.entries == [] or has_upload_errors?(@uploads.image)}
                >
                  Upload
                </button>
              </div>
            </form>
          </div>

          <div :if={not @can_upload} class="alert alert-info">
            <.icon name="hero-information-circle" />
            <span>Maximum of {@max_images} images reached. Delete an image to upload more.</span>
          </div>

          <div :if={@images != []} class="space-y-4">
            <h3 class="font-semibold">Current Images ({length(@images)}/{@max_images})</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div :for={image <- @images} class="card bg-base-100 shadow">
                <figure class="h-32 overflow-hidden">
                  <img src={Uploads.image_url(image.image_key)} class="object-cover w-full h-full" />
                </figure>
                <div class="card-body p-3">
                  <div class="flex justify-between items-center">
                    <span :if={image.is_cover} class="badge badge-soft badge-sm">Cover</span>
                    <span :if={not image.is_cover} class="badge badge-ghost badge-sm">Image</span>
                    <div class="flex gap-1">
                      <button
                        :if={not image.is_cover}
                        phx-click="set_cover"
                        phx-value-id={image.id}
                        class="btn btn-xs btn-outline"
                      >
                        Cover
                      </button>
                      <button
                        phx-click="delete_image"
                        phx-value-id={image.id}
                        data-confirm="Delete this image?"
                        class="btn btn-xs btn-error btn-outline"
                      >
                        <.icon name="hero-trash" class="size-3" />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div :if={@images == []} class="text-center py-8 text-base-content/60">
            <.icon name="hero-photo" class="size-12 mx-auto mb-4" />
            <p>No images yet. Upload your first image above.</p>
          </div>
        </div>
      </.modal>

      <div class="mt-6">
        <.markdown_document document={@document} focused_block_id={@focused_block_id} />
      </div>

      <div class="mt-4 text-xs text-base-content/40">
        <span :if={@focused_block_id}>
          Editing block: focused_block_id={@focused_block_id} cursor_offset={@cursor_offset}
        </span>
        <span :if={!@focused_block_id}>Click on text to edit</span>
      </div>
      <div><span class="badge">{Enum.count(@document.blocks)} blocks</span></div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    note = Notes.get_note!(socket.assigns.current_scope, id)
    document = parse_body(note.body)
    images = Uploads.list_images_for_note(note.id)
    can_upload = length(images) < Uploads.max_images_per_note()

    {:ok,
     socket
     |> assign(:page_title, note.title || "Untitled")
     |> assign(:note, note)
     |> assign(:title, note.title || "")
     |> assign(:document, document)
     |> assign(:focused_block_id, nil)
     |> assign(:cursor_offset, 0)
     |> assign(:dirty, false)
     |> assign(:images, images)
     |> assign(:max_images, Uploads.max_images_per_note())
     |> assign(:can_upload, can_upload)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    socket =
      if socket.assigns.live_action == :images and socket.assigns.can_upload do
        allow_upload(socket, :image,
          accept: ~w(.jpg .jpeg .png .webp),
          max_entries: 1,
          max_file_size: 10_000_000,
          external: &presign_upload/2
        )
      else
        socket
      end

    {:noreply, socket}
  end

  defp presign_upload(entry, socket) do
    note = socket.assigns.note
    user_id = socket.assigns.current_scope.user.id

    extension =
      entry.client_name |> Path.extname() |> String.trim_leading(".") |> String.downcase()

    {key, url} = Uploads.presigned_upload_url(user_id, note.id, extension)

    {:ok, %{uploader: "S3", key: key, url: url}, socket}
  end

  # Handle cursor movement from JS hook - select/focus a block
  @impl true
  def handle_event("block_selected", %{"block_id" => block_id} = params, socket) do
    offset = Map.get(params, "offset", 0)

    {:noreply,
     socket
     |> assign(:focused_block_id, block_id)
     |> assign(:cursor_offset, offset)}
  end

  # Handle up/down arrow navigation between blocks
  def handle_event("navigate_block", %{"block_id" => block_id, "direction" => direction}, socket) do
    doc = socket.assigns.document

    target_id =
      case direction do
        "up" -> Document.previous_block_id(doc, block_id) || Document.first_block_id(doc)
        "down" -> Document.next_block_id(doc, block_id) || Document.last_block_id(doc)
        _ -> nil
      end

    if target_id do
      {:noreply,
       socket
       |> assign(:focused_block_id, target_id)
       |> push_event("focus_block", %{block_id: target_id})}
    else
      {:noreply, socket}
    end
  end

  # Handle content changes from focused block
  def handle_event(
        "block_content_changed",
        %{"block_id" => block_id, "content" => content},
        socket
      ) do
    # dbg(socket.assigns.document)
    document = Document.update_block(socket.assigns.document, block_id, content)
    # dbg(document)

    {:noreply,
     socket
     |> assign(:document, document)
     |> assign(:dirty, true)}
  end

  # Handle blur - unfocus block and sync content
  def handle_event("blur_block", %{"block_id" => block_id, "value" => value}, socket) do
    # Only unfocus if we're still focused on this block
    # (keydown Enter may have already moved focus to a new block)
    # dbg({:parsing, block_id, value})

    if socket.assigns.focused_block_id == block_id do
      # dbg("socket.assigns.focused_block_id == block_id")
      # Trim trailing whitespace
      trimmed_value = String.trim_trailing(value)

      cond do
        trimmed_value == "" ->
          # Remove empty block from document
          # dbg("trimmed_value is empty")
          document = Document.remove_block(socket.assigns.document, block_id)

          {:noreply,
           socket
           |> assign(:document, document)
           |> assign(:focused_block_id, nil)
           |> assign(:dirty, true)}

        not Parser.empty?(value) ->
          dbg("raw value is NOT empty [#{trimmed_value}]")
          # Update block with trimmed content, then re-parse
          document = Document.update_block(socket.assigns.document, block_id, trimmed_value)
          body = Parser.to_markdown(document)
          document = Parser.parse(body)

          {:noreply,
           socket
           |> assign(:document, document)
           |> assign(:focused_block_id, block_id)
           |> assign(:dirty, true)}

        true ->
          # dbg("trimmed_value is WIP [#{trimmed_value}]")
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Create first block when clicking on empty document
  # TODO - this can be generalized
  #
  def handle_event("create_first_block", _params, socket) do
    {document, new_id} = Document.new_block(%Document{blocks: []})

    {:noreply,
     socket
     |> assign(:document, document)
     |> assign(:focused_block_id, new_id)
     |> assign(:dirty, true)
     |> push_event("focus_block", %{block_id: new_id})}
  end

  # Save the note
  def handle_event("save", _params, socket) do
    body = Parser.to_markdown(socket.assigns.document)

    case Notes.update_note(
           socket.assigns.current_scope,
           socket.assigns.note,
           %{title: socket.assigns.title, body: body}
         ) do
      {:ok, note} ->
        {:noreply,
         socket
         |> assign(:note, note)
         |> assign(:dirty, false)
         |> put_flash(:info, "Saved")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save")}
    end
  end

  # === keyboard shortcut events from JS

  # Handle Enter key - split block at cursor position
  def handle_event(
        "split_block",
        %{"block_id" => block_id, "cursor_position" => cursor_position, "content" => content},
        socket
      ) do
    if socket.assigns.focused_block_id == block_id do
      {:ok, document, new_id} =
        Document.split_block(socket.assigns.document, block_id, content, cursor_position)

      {:noreply,
       socket
       |> assign(:document, document)
       |> assign(:focused_block_id, new_id)
       |> assign(:dirty, true)
       |> push_event("focus_block", %{block_id: new_id})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("keydown", _params, socket) do
    {:noreply, socket}
  end

  # Handle Backspace at beginning of block - merge with previous
  def handle_event("merge_with_previous", %{"block_id" => block_id, "content" => content}, socket) do
    case Document.merge_with_previous(socket.assigns.document, block_id, content) do
      {:ok, document, prev_block_id, cursor_offset} ->
        {:noreply,
         socket
         |> assign(:document, document)
         |> assign(:focused_block_id, prev_block_id)
         |> assign(:dirty, true)
         |> push_event("focus_block_at", %{block_id: prev_block_id, offset: cursor_offset})}

      :error ->
        # First block, nothing to merge
        {:noreply, socket}
    end
  end

  # === TITLE events
  # Handle title updates
  def handle_event("update_title", %{"title" => title}, socket) do
    {:noreply,
     socket
     |> assign(:title, title)
     |> assign(:dirty, true)}
  end

  # Handle title blur - trim trailing whitespace
  def handle_event("blur_title", %{"value" => value}, socket) do
    trimmed = String.trim_trailing(value)

    {:noreply,
     socket
     |> assign(:title, trimmed)
     |> assign(:dirty, socket.assigns.title != trimmed or socket.assigns.dirty)}
  end

  # === Image upload handlers
  def handle_event("upload_validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  def handle_event("upload_save", _params, socket) do
    uploaded_keys =
      consume_uploaded_entries(socket, :image, fn %{key: key}, _entry ->
        {:ok, key}
      end)

    case uploaded_keys do
      [key] ->
        is_cover = socket.assigns.images == []

        {:ok, _image} =
          Uploads.create_image(%{
            image_key: key,
            note_id: socket.assigns.note.id,
            is_cover: is_cover
          })

        images = Uploads.list_images_for_note(socket.assigns.note.id)
        can_upload = length(images) < Uploads.max_images_per_note()

        {:noreply,
         socket
         |> assign(:images, images)
         |> assign(:can_upload, can_upload)
         |> put_flash(:info, "Image uploaded successfully")}

      [] ->
        {:noreply, socket}
    end
  end

  def handle_event("set_cover", %{"id" => id}, socket) do
    image = Uploads.get_image!(id)

    if image.note_id == socket.assigns.note.id do
      {:ok, _} = Uploads.set_cover(image)
      images = Uploads.list_images_for_note(socket.assigns.note.id)
      {:noreply, assign(socket, :images, images)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_image", %{"id" => id}, socket) do
    image = Uploads.get_image!(id)

    if image.note_id == socket.assigns.note.id do
      {:ok, _} = Uploads.delete_image(image)
      images = Uploads.list_images_for_note(socket.assigns.note.id)
      can_upload = length(images) < Uploads.max_images_per_note()

      {:noreply,
       socket
       |> assign(:images, images)
       |> assign(:can_upload, can_upload)
       |> put_flash(:info, "Image deleted")}
    else
      {:noreply, socket}
    end
  end

  defp has_upload_errors?(upload) do
    not Enum.empty?(upload_errors(upload)) or
      Enum.any?(upload.entries, fn entry -> not Enum.empty?(upload_errors(upload, entry)) end)
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "Invalid file type. Use jpg, png, or webp."
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(err), do: "Error: #{inspect(err)}"

  defp parse_body(nil), do: %Document{blocks: []}
  defp parse_body(""), do: %Document{blocks: []}
  defp parse_body(body), do: Parser.parse(body)
end
