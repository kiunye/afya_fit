defmodule AfyaFitWeb.API.ErrorView do
  @moduledoc false

  def render("404.json", _assigns) do
    %{error: "Resource not found"}
  end

  def render("401.json", _assigns) do
    %{error: "Unauthorized"}
  end

  def render("403.json", _assigns) do
    %{error: "Forbidden"}
  end

  def render("422.json", %{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  def render("500.json", _assigns) do
    %{error: "Internal server error"}
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
