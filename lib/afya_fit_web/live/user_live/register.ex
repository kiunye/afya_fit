defmodule AfyaFitWeb.UserLive.Register do
  use AfyaFitWeb, :live_view

  alias AfyaFit.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <.header>
          Register
          <:subtitle>
            Already have an account?
            <.link navigate={~p"/users/log_in"} class="font-semibold text-brand hover:underline">
              Sign in
            </.link>
            instead.
          </:subtitle>
        </.header>
        
        <.form
          for={@form}
          id="registration_form"
          phx-change="validate"
          phx-submit="save"
          phx-trigger-action={@trigger_submit}
          action={~p"/users/log_in?_action=registered"}
          method="post"
        >
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:password]} type="password" label="Password" required />
          <.input field={@form[:first_name]} type="text" label="First Name" required />
          <.input field={@form[:last_name]} type="text" label="Last Name" required />
          <.input
            field={@form[:role]}
            type="select"
            label="I am a"
            options={[{"Trainer", "trainer"}, {"Client", "client"}]}
            required
          />
          <%= if @show_organization_fields do %>
            <.input
              field={@form[:organization_name]}
              type="text"
              label="Organization/Business Name"
              required
            />
            <.input
              field={@form[:organization_subdomain]}
              type="text"
              label="Subdomain"
              placeholder="your-gym-name"
              required
            />
            <p class="text-sm text-gray-600 mt-1">
              This will be your unique URL: <span class="font-mono">your-gym-name.afyafit.com</span>
            </p>
          <% else %>
            <.input
              field={@form[:organization_subdomain]}
              type="text"
              label="Organization Subdomain"
              placeholder="your-trainer-subdomain"
              required
            />
            <p class="text-sm text-gray-600 mt-1">
              Enter your trainer's organization subdomain to join their account.
            </p>
          <% end %>
          
          <div>
            <.button phx-disable-with="Creating account..." class="w-full">Create an account</.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%Accounts.User{})

    socket =
      socket
      |> assign(:trigger_submit, false)
      |> assign(:show_organization_fields, false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    role = user_params["role"]
    show_org_fields = role == "trainer"

    changeset =
      %Accounts.User{}
      |> Accounts.change_user_registration(user_params)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(:show_organization_fields, show_org_fields)
      |> assign_form(changeset)

    {:noreply, socket}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_with_organization(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
