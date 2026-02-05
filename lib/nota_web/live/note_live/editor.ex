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
  alias NotaWeb.NoteLive.WikiLinkAutocomplete

  import NotaWeb.MarkdownComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        <form id="title-form" phx-change="update_title" phx-submit="update_title" class="flex-1">
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
          <span class="text-base-content/40">
            {Calendar.strftime(@note.inserted_at, "%Y/%m/%d")} - creation
          </span>
        </:subtitle>
        <:actions>
          <.button navigate={back_path(@note)}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button :if={@has_unsaved_changes} variant="primary" phx-click="save">
            <.icon name="hero-check" /> Save
          </.button>
          <span :if={!@has_unsaved_changes} class="text-sm text-base-content/50">Saved</span>
          <div class="dropdown dropdown-end">
            <.button tabindex="0">
              <.icon name="hero-ellipsis-vertical" />
            </.button>
            <ul
              tabindex="0"
              class="dropdown-content menu bg-base-200 rounded-box z-10 w-52 p-2 shadow-sm"
            >
              <li>
                <a phx-click="delete" data-confirm="Are you sure you want to delete this note?">
                  <.icon name="hero-trash" class="text-error" /> Delete Note
                </a>
              </li>
            </ul>
          </div>
        </:actions>
      </.header>

      <div class="mt-6 relative">
        <.markdown_document document={@document} focused_block_id={@focused_block_id} />

        <.live_component
          :if={@show_autocomplete}
          module={WikiLinkAutocomplete}
          id="wiki-link-autocomplete"
          position={@autocomplete_position}
          block_id={@autocomplete_block_id}
          current_scope={@current_scope}
        />

        <%!-- Hidden form for drag/drop image upload --%>
        <form
          id="drop-upload-form"
          phx-change="drop_validate"
          phx-submit="drop_image_save"
          class="hidden"
        >
          <.live_file_input upload={@uploads.drop_image} id="drop-image-input" />
        </form>
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

    {:ok,
     socket
     |> assign(:page_title, note.title || "Untitled")
     |> assign(:note, note)
     |> assign(:title, note.title || "")
     |> assign(:document, document)
     |> assign(:focused_block_id, nil)
     |> assign(:cursor_offset, 0)
     |> assign(:has_unsaved_changes, false)
     |> assign(:show_autocomplete, false)
     |> assign(:autocomplete_position, %{top: 0, left: 0})
     |> assign(:autocomplete_block_id, nil)
     |> assign(:autocomplete_start_pos, nil)
     # Drag/drop image upload state
     |> assign(:drop_target_block_id, nil)
     |> assign(:is_dragging, false)
     |> allow_upload(:drop_image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 10_000_000,
       external: &presign_upload/2,
       auto_upload: true,
       progress: &handle_drop_progress/3
     )}
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
     |> assign(:has_unsaved_changes, true)}
  end

  # Handle blur - unfocus block and sync content
  def handle_event("blur_block", %{"block_id" => block_id, "value" => value}, socket) do
    # Skip blur processing if autocomplete is open (user is just interacting with autocomplete)
    if socket.assigns.show_autocomplete do
      {:noreply, socket}
    else
      handle_blur_block(socket, block_id, value)
    end
  end

  # Create first block when clicking on empty document
  def handle_event("create_first_block", _params, socket) do
    {document, new_id} = Document.new_block(%Document{blocks: []})

    {:noreply,
     socket
     |> assign(:document, document)
     |> assign(:focused_block_id, new_id)
     |> assign(:has_unsaved_changes, true)
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
         |> assign(:has_unsaved_changes, false)
         |> put_flash(:info, "Saved")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save")}
    end
  end

  # Delete the note
  def handle_event("delete", _params, socket) do
    case Notes.delete_note(socket.assigns.current_scope, socket.assigns.note) do
      {:ok, _note} ->
        {:noreply,
         socket
         |> put_flash(:info, "Note deleted")
         |> push_navigate(to: back_path(socket.assigns.note))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete note")}
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
       |> assign(:has_unsaved_changes, true)
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
         |> assign(:has_unsaved_changes, true)
         |> push_event("focus_block_at", %{block_id: prev_block_id, offset: cursor_offset})}

      :error ->
        # First block, nothing to merge
        {:noreply, socket}
    end
  end

  # === Wiki-link autocomplete events

  # Show autocomplete dropdown when [[ is typed
  def handle_event(
        "show_autocomplete",
        %{"block_id" => block_id, "start_pos" => start_pos, "top" => top, "left" => left},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:show_autocomplete, true)
     |> assign(:autocomplete_position, %{top: top, left: left})
     |> assign(:autocomplete_block_id, block_id)
     |> assign(:autocomplete_start_pos, start_pos)}
  end

  # Close autocomplete dropdown
  def handle_event("close_autocomplete", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_autocomplete, false)
     |> push_event("autocomplete_closed", %{block_id: socket.assigns.autocomplete_block_id})}
  end

  # === TITLE events
  # Handle title updates
  def handle_event("update_title", %{"title" => title}, socket) do
    {:noreply,
     socket
     |> assign(:title, title)
     |> assign(:has_unsaved_changes, true)}
  end

  # Handle title blur - trim trailing whitespace
  def handle_event("blur_title", %{"value" => value}, socket) do
    trimmed = String.trim_trailing(value)

    {:noreply,
     socket
     |> assign(:title, trimmed)
     |> assign(
       :has_unsaved_changes,
       socket.assigns.title != trimmed or socket.assigns.has_unsaved_changes
     )}
  end

  # === Drag/drop image upload handlers

  def handle_event("drop_image_start", %{"target_block_id" => target_block_id}, socket) do
    {:noreply,
     socket
     |> assign(:drop_target_block_id, target_block_id)
     |> assign(:is_dragging, true)}
  end

  def handle_event("drop_image_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(:drop_target_block_id, nil)
     |> assign(:is_dragging, false)}
  end

  def handle_event("drop_validate", _params, socket) do
    {:noreply, socket}
  end

  # Keep the form submit handler as a no-op since auto_upload handles everything
  def handle_event("drop_image_save", _params, socket) do
    {:noreply, socket}
  end

  # Delete a block (used for image blocks via keyboard)
  def handle_event("delete_block", %{"block_id" => block_id}, socket) do
    document = Document.remove_block(socket.assigns.document, block_id)
    prev_id = Document.previous_block_id(socket.assigns.document, block_id)
    next_id = Document.next_block_id(socket.assigns.document, block_id)

    # Focus the previous block, or the next, or nil if empty
    focus_id = prev_id || next_id

    socket =
      socket
      |> assign(:document, document)
      |> assign(:focused_block_id, focus_id)
      |> assign(:has_unsaved_changes, true)

    socket =
      if focus_id do
        push_event(socket, "focus_block", %{block_id: focus_id})
      else
        socket
      end

    {:noreply, socket}
  end

  # Progress callback for drop_image upload - called when upload completes
  defp handle_drop_progress(:drop_image, entry, socket) do
    if entry.done? do
      # Extract original filename (without extension) for alt text
      alt_text = Path.basename(entry.client_name, Path.extname(entry.client_name))

      # Upload completed - consume and create image block
      uploaded_keys =
        consume_uploaded_entries(socket, :drop_image, fn %{key: key}, _entry ->
          {:ok, key}
        end)

      case uploaded_keys do
        [image_key] ->
          # Create image record in database
          {:ok, _image} =
            Uploads.create_image(%{
              image_key: image_key,
              note_id: socket.assigns.note.id
            })

          # Create ImageBlock and insert into document with filename as alt text
          {document, new_id} =
            Document.new_image_block(
              socket.assigns.document,
              image_key,
              after: socket.assigns.drop_target_block_id,
              alt_text: alt_text
            )

          {:noreply,
           socket
           |> assign(:document, document)
           |> assign(:drop_target_block_id, nil)
           |> assign(:is_dragging, false)
           |> assign(:has_unsaved_changes, true)
           |> push_event("focus_block", %{block_id: new_id})}

        [] ->
          {:noreply,
           socket
           |> assign(:drop_target_block_id, nil)
           |> assign(:is_dragging, false)}
      end
    else
      # Upload still in progress
      {:noreply, socket}
    end
  end

  # === handle_info callbacks

  # Note link selected from autocomplete
  @impl true
  def handle_info({:note_link_selected, note_id, title, block_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_autocomplete, false)
     |> push_event("insert_note_link", %{
       block_id: block_id,
       note_id: note_id,
       title: title,
       start_pos: socket.assigns.autocomplete_start_pos
     })}
  end

  # Close autocomplete without selection
  def handle_info(:close_autocomplete, socket) do
    {:noreply,
     socket
     |> assign(:show_autocomplete, false)
     |> push_event("autocomplete_closed", %{block_id: socket.assigns.autocomplete_block_id})}
  end

  # === Private functions for blur handling

  defp handle_blur_block(socket, block_id, value) do
    # Only process if we're still focused on this block
    # (keydown Enter may have already moved focus to a new block)
    if socket.assigns.focused_block_id != block_id do
      {:noreply, socket}
    else
      process_blur_block(socket, block_id, value)
    end
  end

  defp process_blur_block(socket, block_id, value) do
    trimmed_value = String.trim_trailing(value)

    cond do
      trimmed_value == "" ->
        # Remove empty block from document
        document = Document.remove_block(socket.assigns.document, block_id)

        {:noreply,
         socket
         |> assign(:document, document)
         |> assign(:focused_block_id, nil)
         |> assign(:has_unsaved_changes, true)}

      not Parser.empty_content?(value) ->
        handle_content_blur(socket, block_id, trimmed_value)

      true ->
        {:noreply, socket}
    end
  end

  defp handle_content_blur(socket, block_id, trimmed_value) do
    current_source = Document.get_block_source(socket.assigns.document, block_id)

    if current_source == trimmed_value do
      # No change, just clear focus
      {:noreply, assign(socket, :focused_block_id, nil)}
    else
      # Update block with trimmed content, then re-parse
      document = Document.update_block(socket.assigns.document, block_id, trimmed_value)
      body = Parser.to_markdown(document)
      document = Parser.parse(body)

      {:noreply,
       socket
       |> assign(:document, document)
       |> assign(:focused_block_id, block_id)
       |> assign(:has_unsaved_changes, true)}
    end
  end

  defp parse_body(nil), do: %Document{blocks: []}
  defp parse_body(""), do: %Document{blocks: []}
  defp parse_body(body), do: Parser.parse(body)

  defp back_path(%{contact_id: nil}), do: ~p"/notes"
  defp back_path(%{contact_id: contact_id}), do: ~p"/contacts/#{contact_id}"
end
