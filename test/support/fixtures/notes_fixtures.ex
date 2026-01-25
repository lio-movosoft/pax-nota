defmodule Nota.NotesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Nota.Notes` context.
  """

  @doc """
  Generate a note.
  """
  def note_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        body: "some body",
        title: "some title"
      })

    {:ok, note} = Nota.Notes.create_note(scope, attrs)
    note
  end
end
