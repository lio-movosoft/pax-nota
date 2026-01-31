defmodule Nota.Uploads do
  @moduledoc """
  Context for handling note image uploads to S3/MinIO.
  """

  import Ecto.Query

  alias Nota.Notes.NoteImage
  alias Nota.Repo

  @doc """
  Returns all images for a note.
  """
  def list_images_for_note(note_id) do
    NoteImage
    |> where(note_id: ^note_id)
    |> order_by([i], asc: i.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single note image.
  """
  def get_image!(id), do: Repo.get!(NoteImage, id)

  @doc """
  Creates a note image record after successful upload.
  """
  def create_image(attrs) do
    %NoteImage{}
    |> NoteImage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a note image from database and S3.
  """
  def delete_image(%NoteImage{} = image) do
    delete_from_s3(image.image_key)
    Repo.delete(image)
  end

  @doc """
  Deletes all images for a note from database and S3.
  Called when a note is deleted.
  """
  def delete_all_images_for_note(note_id) do
    images = list_images_for_note(note_id)
    Enum.each(images, &delete_image/1)
    :ok
  end

  @doc """
  Extracts image keys from note body markdown.
  Matches ![alt](image_key) patterns.
  """
  def parse_image_keys(nil), do: []
  def parse_image_keys(""), do: []

  def parse_image_keys(body) when is_binary(body) do
    ~r/!\[[^\]]*\]\(([^)]+)\)/
    |> Regex.scan(body)
    |> Enum.map(fn [_, key] -> key end)
    |> Enum.uniq()
  end

  @doc """
  Syncs image records with what's actually referenced in the note body.
  Deletes orphaned images (those in DB but not in markdown).
  Called after note save.
  """
  def sync_images_for_note(note_id, body) do
    referenced_keys = parse_image_keys(body) |> MapSet.new()
    existing_images = list_images_for_note(note_id)

    # Find orphaned images (in DB but not in markdown)
    orphaned_images =
      Enum.reject(existing_images, fn image ->
        MapSet.member?(referenced_keys, image.image_key)
      end)

    # Delete each orphan (S3 file + DB record)
    Enum.each(orphaned_images, &delete_image/1)

    :ok
  end

  @doc """
  Returns the count of images for a note.
  """
  def count_images_for_note(note_id) do
    NoteImage
    |> where(note_id: ^note_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Generates a pre-signed URL for uploading to S3/MinIO.
  """
  def presigned_upload_url(user_id, note_id, extension) do
    config = s3_config()
    image_id = generate_image_id()
    key = "#{user_id}_#{note_id}_#{image_id}.#{extension}"

    {:ok, url} =
      ExAws.S3.presigned_url(
        ExAws.Config.new(:s3, config),
        :put,
        config[:bucket],
        key,
        expires_in: 300,
        query_params: [{"Content-Type", content_type(extension)}]
      )

    {key, url}
  end

  @doc """
  Returns a presigned URL for reading an image.
  URL expires in 1 hour.
  """
  def image_url(image_key) do
    config = s3_config()

    {:ok, url} =
      ExAws.S3.presigned_url(
        ExAws.Config.new(:s3, config),
        :get,
        config[:bucket],
        image_key,
        expires_in: 3600
      )

    url
  end

  defp delete_from_s3(image_key) do
    config = s3_config()

    try do
      ExAws.S3.delete_object(config[:bucket], image_key)
      |> ExAws.request(config)
    rescue
      # In test environment, hackney may not be available
      UndefinedFunctionError -> :ok
    end
  end

  defp s3_config do
    config = Application.get_env(:nota, :s3)

    [
      access_key_id: config[:access_key_id],
      secret_access_key: config[:secret_access_key],
      region: config[:region],
      host: config[:host],
      port: config[:port],
      scheme: config[:scheme],
      bucket: config[:bucket]
    ]
  end

  defp generate_image_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  defp content_type("jpg"), do: "image/jpeg"
  defp content_type("jpeg"), do: "image/jpeg"
  defp content_type("png"), do: "image/png"
  defp content_type("webp"), do: "image/webp"
  defp content_type(_), do: "application/octet-stream"
end
