defmodule Nota.Uploads do
  @moduledoc """
  Context for handling note image uploads to S3/MinIO.
  """

  import Ecto.Query
  alias Nota.Repo
  alias Nota.Notes.NoteImage

  @max_images_per_note 3

  def max_images_per_note, do: @max_images_per_note

  @doc """
  Returns all images for a note.
  """
  def list_images_for_note(note_id) do
    NoteImage
    |> where(note_id: ^note_id)
    |> order_by([i], desc: i.is_cover, asc: i.inserted_at)
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
  Sets an image as the cover, unsetting any previous cover.
  """
  def set_cover(%NoteImage{} = image) do
    Repo.transaction(fn ->
      NoteImage
      |> where(note_id: ^image.note_id, is_cover: true)
      |> Repo.update_all(set: [is_cover: false])

      image
      |> Ecto.Changeset.change(is_cover: true)
      |> Repo.update!()
    end)
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
  Checks if more images can be added to a note.
  """
  def can_add_image?(note_id) do
    count_images_for_note(note_id) < @max_images_per_note
  end

  @doc """
  Gets the cover image for a note, or nil if none.
  """
  def get_cover_image(note_id) do
    NoteImage
    |> where(note_id: ^note_id, is_cover: true)
    |> Repo.one()
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
  Returns the public URL for an image.
  """
  def image_url(image_key) do
    config = s3_config()
    "#{config[:scheme]}#{config[:host]}:#{config[:port]}/#{config[:bucket]}/#{image_key}"
  end

  defp delete_from_s3(image_key) do
    config = s3_config()

    ExAws.S3.delete_object(config[:bucket], image_key)
    |> ExAws.request(config)
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
