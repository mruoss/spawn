defmodule Statestores.Adapters.MySQL do
  @moduledoc """
  Implements the behavior defined in `Statestores.Adapters.Behaviour` for MySql databases.
  """
  use Statestores.Adapters.Behaviour

  use Ecto.Repo,
    otp_app: :spawn_statestores,
    adapter: Ecto.Adapters.MyXQL

  alias Statestores.Schemas.{Snapshot, ValueObjectSchema}

  def get_by_key(id), do: get_by(Snapshot, id: id)

  def save(
        %Snapshot{
          system: system,
          actor: actor,
          revision: revision,
          tags: tags,
          data_type: type,
          data: data
        } = event
      ) do
    %Snapshot{}
    |> Snapshot.changeset(ValueObjectSchema.to_map(event))
    |> insert_or_update(
      on_conflict: [
        set: [
          system: system,
          actor: actor,
          revision: revision,
          tags: tags,
          data_type: type,
          data: data,
          updated_at: DateTime.utc_now()
        ]
      ]
    )
    |> case do
      {:ok, event} ->
        {:ok, event}

      {:error, changeset} ->
        {:error, changeset}

      other ->
        {:error, other}
    end
  end

  def default_port, do: "3306"
end
