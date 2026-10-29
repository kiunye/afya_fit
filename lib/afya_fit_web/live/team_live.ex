defmodule AfyaFitWeb.TeamLive do
  @moduledoc """
  Team: the trainers in the organization. Organization admins add trainers and
  remove them; removing one moves their clients, plans and tasks to the admin.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.Accounts.User
  alias AfyaFit.{Authorization, Team}
  alias AfyaFitWeb.Access

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Access.guard(:list, :trainer)
      |> assign(:page_title, "Team")
      |> assign(:form, nil)
      |> assign(:confirm_remove, nil)

    if socket.assigns.denied, do: {:ok, socket}, else: {:ok, load(socket)}
  end

  defp load(socket) do
    scope = socket.assigns.current_scope
    members = Team.list_members(scope)

    socket
    |> assign(:count, length(members))
    |> stream(:members, members, reset: true)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:team}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />

      <div :if={!@denied} id="team">
        <.page_header>
          Team
          <:subtitle>
            <b class="text-ink">
              {@count} {if @count == 1, do: "trainer", else: "trainers"}, you included.
            </b>
            Each sees only the clients you assign them.
          </:subtitle>
        </.page_header>

        <.sign_group label="Trainers">
          <:actions>
            <.sign_action :if={!@form} id="add-trainer" primary phx-click="new_trainer">
              Add trainer
            </.sign_action>
          </:actions>

          <.form
            :if={@form}
            for={@form}
            id="trainer-form"
            phx-submit="invite"
            phx-change="validate"
            class="max-w-2xl border-b border-line/40 px-4 pb-6 pt-2 sm:px-[26px]"
          >
            <p class="mb-4 text-ink-2">
              They get an email to set a password. They can see only the clients you assign them.
            </p>
            <div class="grid gap-x-6 sm:grid-cols-2">
              <.input field={@form[:first_name]} type="text" label="First name" required />
              <.input field={@form[:last_name]} type="text" label="Last name" required />
            </div>
            <.input field={@form[:email]} type="email" label="Email" required />
            <div class="mt-4 flex gap-3">
              <.button type="submit" variant="primary">Add trainer</.button>
              <.button type="button" phx-click="cancel_new">Cancel</.button>
            </div>
          </.form>

          <div id="members" phx-update="stream">
            <.sign
              :for={{id, member} <- @streams.members}
              id={id}
              icon={:team}
              draw={false}
              time={to_string(member.client_count)}
              time_label="Clients"
            >
              <:title>
                {member.user.first_name} {member.user.last_name}
                <span
                  :if={member.user.role == "org_admin"}
                  class="ml-2 rounded-[3px] border-2 border-line px-1.5 align-[2px] text-xs font-bold uppercase tracking-[.06em]"
                >
                  Owner
                </span>
              </:title>
              {member.user.email}
              <:actions :if={member.user.role == "trainer"}>
                <.sign_action
                  id={"remove-#{member.user.id}"}
                  phx-click="ask_remove"
                  phx-value-id={member.user.id}
                >
                  Remove
                </.sign_action>
              </:actions>
            </.sign>
          </div>

          <.sign
            :if={@confirm_remove}
            id="remove-confirm"
            icon={:alert}
            state={:next}
            draw={false}
            time={to_string(@confirm_remove.client_count)}
            time_label="Clients move"
          >
            <:title>
              Remove {@confirm_remove.user.first_name} {@confirm_remove.user.last_name}?
            </:title>
            Their {@confirm_remove.client_count} clients, plans and tasks move to you. This is
            recorded in the activity log.
            <:actions>
              <.sign_action id="confirm-remove" primary phx-click="remove">
                Remove trainer
              </.sign_action>
              <.sign_action id="keep-trainer" phx-click="cancel_remove">Keep</.sign_action>
            </:actions>
          </.sign>
        </.sign_group>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("new_trainer", _params, socket) do
    case Authorization.authorize(socket.assigns.current_scope, :create, :trainer) do
      :ok ->
        {:noreply,
         assign(
           socket,
           :form,
           to_form(User.trainer_invite_changeset(%User{}, %{}), as: "trainer")
         )}

      error ->
        {:noreply, Access.flash_denial(socket, error)}
    end
  end

  def handle_event("cancel_new", _params, socket), do: {:noreply, assign(socket, :form, nil)}

  def handle_event("validate", %{"trainer" => params}, socket) do
    changeset = %User{} |> User.trainer_invite_changeset(params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, :form, to_form(changeset, as: "trainer"))}
  end

  def handle_event("invite", %{"trainer" => params}, socket) do
    scope = socket.assigns.current_scope

    case Team.invite_trainer(scope, params, &url(~p"/users/reset_password/#{&1}")) do
      {:ok, trainer} ->
        {:noreply,
         socket
         |> assign(:form, nil)
         |> put_flash(:info, "Trainer added. We emailed #{trainer.email} to set a password.")
         |> load()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "trainer"))}

      error ->
        {:noreply, Access.flash_denial(socket, error)}
    end
  end

  def handle_event("ask_remove", %{"id" => id}, socket) do
    member = Team.get_member(socket.assigns.current_scope, id)
    {:noreply, assign(socket, :confirm_remove, member)}
  end

  def handle_event("cancel_remove", _params, socket),
    do: {:noreply, assign(socket, :confirm_remove, nil)}

  def handle_event("remove", _params, socket) do
    scope = socket.assigns.current_scope
    %{user: trainer} = socket.assigns.confirm_remove

    case Team.remove_trainer(scope, trainer.id) do
      {:ok, %{clients_moved: moved}} ->
        {:noreply,
         socket
         |> assign(:confirm_remove, nil)
         |> put_flash(
           :info,
           "Trainer removed. #{moved} #{if moved == 1, do: "client", else: "clients"} moved to you."
         )
         |> load()}

      error ->
        {:noreply, socket |> assign(:confirm_remove, nil) |> Access.flash_denial(error)}
    end
  end
end
