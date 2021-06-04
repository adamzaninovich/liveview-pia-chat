defmodule ChatWeb.RoomLive do
  use ChatWeb, :live_view
  alias Chat.Message
  require Logger

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    topic = "room:#{room_id}"
    username = MnemonicSlugs.generate_slug(2)
    user_id = "user:#{username}"

    # username becomes user id, also stored in meta as username which the user
    # can change later

    if connected?(socket) do
      ChatWeb.Endpoint.subscribe(topic)
      ChatWeb.Presence.track(self(), topic, user_id, %{username: username})
    end

    {:ok,
     assign(socket,
       room_id: room_id,
       topic: topic,
       editing_user: false,
       user_id: user_id,
       username: username,
       users: [],
       message: "",
       messages: [],
       temporary_assigns: [messages: []]
     )}
  end

  @impl true
  def handle_event("submit_message", %{"chat" => %{"message" => text}}, socket) do
    message = Message.new(socket.assigns.username, text)
    ChatWeb.Endpoint.broadcast(socket.assigns.topic, "new_message", message)
    {:noreply, assign(socket, message: "")}
  end

  def handle_event("form_update", %{"chat" => %{"message" => message}}, socket) do
    {:noreply, assign(socket, message: message)}
  end

  def handle_event("edit_on", _params, socket) do
    {:noreply, assign(socket, editing_user: true)}
  end

  def handle_event("edit_off", _params, socket) do
    {:noreply, assign(socket, editing_user: false)}
  end

  def handle_event("submit_name", %{"user" => %{"name" => name}}, socket) do
    %{topic: topic, user_id: user_id} = socket.assigns
    ChatWeb.Presence.update(self(), topic, user_id, %{username: name})
    {:noreply, assign(socket, username: name, editing_user: false)}
  end

  @impl true
  def handle_info(%{event: "new_message", payload: message}, socket) do
    {:noreply, assign(socket, messages: [message])}
  end

  def handle_info(%{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    changed =
      joins
      |> Map.keys()
      |> Enum.filter(fn user_id -> user_id in Map.keys(leaves) end)

    change_messages =
      Enum.map(changed, fn user_id ->
        %{metas: [%{username: old_username}]} = leaves[user_id]
        %{metas: [%{username: new_username}]} = joins[user_id]
        Message.new("System", "#{old_username} became #{new_username}.")
      end)

    join_messages =
      joins
      |> Enum.reject(fn {id, _meta} -> id in changed end)
      |> Enum.map(fn {_id, %{metas: [%{username: username}]}} ->
        Message.new("System", "#{username} joined the chat.")
      end)

    leave_messages =
      leaves
      |> Enum.reject(fn {id, _meta} -> id in changed end)
      |> Enum.map(fn {_id, %{metas: [%{username: username}]}} ->
        Message.new("System", "#{username} left the chat.")
      end)

    messages = leave_messages ++ join_messages ++ change_messages

    users =
      socket.assigns.topic
      |> ChatWeb.Presence.list()
      |> Enum.map(fn {_id, %{metas: [%{username: username}]}} -> username end)

    {:noreply, assign(socket, messages: messages, users: users)}
  end

  def render_message(%Message{username: "System"} = message) do
    ~E"""
    <p id="<%= message.id %>">
      <em><%= message.text %></em>
    </p>
    """
  end

  def render_message(%Message{} = message) do
    ~E"""
    <p id="<%= message.id %>">
      <strong><%= message.username %></strong>: <%= message.text %>
    </p>
    """
  end
end
