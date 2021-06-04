defmodule Chat.Message do
  defstruct [:id, :timestamp, :username, :text]

  def new(username, text) do
    timestamp = get_timestamp()
    id = make_id(timestamp, username, text)

    %__MODULE__{
      id: id,
      timestamp: timestamp,
      username: username,
      text: text
    }
  end

  defp get_timestamp() do
    DateTime.to_unix(DateTime.utc_now(), :microsecond)
  end

  defp make_id(timestamp, username, text) do
    :sha256
    |> :crypto.hash([to_string(timestamp), username, text])
    |> Base.encode16()
    |> String.downcase()
  end
end
