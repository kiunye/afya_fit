defmodule AfyaFit.Organizations do
  @moduledoc """
  The Organizations context.
  """

  import Ecto.Query, warn: false
  alias AfyaFit.Accounts.User
  alias AfyaFit.Organizations.Organization
  alias AfyaFit.Repo

  def list_organizations do
    Repo.all(Organization)
  end

  def get_organization!(id), do: Repo.get!(Organization, id)

  def create_organization(attrs \\ %{}) do
    %Organization{}
    |> Organization.changeset(attrs)
    |> Repo.insert()
  end

  def update_organization(%Organization{} = organization, attrs) do
    organization
    |> Organization.changeset(attrs)
    |> Repo.update()
  end

  def delete_organization(%Organization{} = organization) do
    Repo.delete(organization)
  end

  def change_organization(%Organization{} = organization, attrs \\ %{}) do
    Organization.changeset(organization, attrs)
  end

  def get_organization_by_subdomain(subdomain) do
    Repo.get_by(Organization, subdomain: subdomain)
  end

  @doc """
  Gets the organization owner/admin user.
  Returns an admin if available, otherwise returns a trainer.
  """
  def get_organization_owner(%Organization{} = organization) do
    # First try to find an admin
    admin =
      User
      |> where([u], u.organization_id == ^organization.id)
      |> where([u], u.role == "admin")
      |> where([u], is_nil(u.deleted_at))
      |> Repo.one()

    if admin do
      admin
    else
      # Fallback to a trainer
      User
      |> where([u], u.organization_id == ^organization.id)
      |> where([u], u.role == "trainer")
      |> where([u], is_nil(u.deleted_at))
      |> Repo.one()
    end
  end
end
