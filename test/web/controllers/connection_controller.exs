defmodule Mithril.Web.ConnectionControllerTest do
  use Mithril.Web.ConnCase

  alias Ecto.UUID
  alias Mithril.Clients

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "list connections" do
    setup %{conn: conn} do
      client = insert(:client)
      {:ok, conn: conn, client: client}
    end

    test "all entries on index", %{conn: conn, client: client} do
      insert_pair(:connection, client: client)

      data =
        conn
        |> get(client_connection_path(conn, :index, client))
        |> json_response(200)
        |> Map.get("data")

      assert 2 == length(data)
    end
  end

  describe "get connection by id" do
    setup %{conn: conn} do
      client = insert(:client)
      consumer = insert(:client)
      {:ok, conn: conn, client: client, consumer: consumer}
    end

    test "success", %{conn: conn, client: client, consumer: consumer} do
      connection = insert(:connection, client: client, consumer: consumer)

      conn
      |> get(client_connection_path(conn, :show, client, connection))
      |> json_response(200)
      |> assert_connection_fields()
    end

    test "invalid connection id", %{conn: conn, client: client, consumer: consumer} do
      assert_error_sent(404, fn ->
        get(conn, client_connection_path(conn, :show, client, consumer))
      end)
    end

    test "invalid client id", %{conn: conn, client: client, consumer: consumer} do
      connection = insert(:connection, client: client, consumer: consumer)

      assert_error_sent(404, fn ->
        get(conn, client_connection_path(conn, :show, consumer, connection))
      end)
    end
  end

  describe "upsert connection" do
    setup %{conn: conn} do
      client = insert(:client)
      consumer = insert(:client)
      {:ok, conn: conn, client: client, consumer: consumer}
    end

    test "success create", %{conn: conn, client: client, consumer: consumer} do
      attrs = %{redirect_uri: "http://localhost", client_id: client.id, consumer_id: consumer.id}

      connection =
        conn
        |> put(client_connection_path(conn, :upsert, client), attrs)
        |> json_response(201)

      assert Map.has_key?(connection["data"], "secret")
    end

    test "success update", %{conn: conn, client: client, consumer: consumer} do
      connection = insert(:connection, client: client, consumer: consumer)
      attrs = %{consumer_id: consumer.id, client_id: client.id, secret: "new secret"}

      data =
        conn
        |> put(client_connection_path(conn, :upsert, client), attrs)
        |> json_response(200)
        |> Map.get("data")

      assert Map.has_key?(data, "secret")
      assert connection.secret == data["secret"]

      %{secret: db_secret} = Clients.get_connection!(connection.id)
      assert connection.secret == db_secret
    end

    test "refresh secret", %{conn: conn, client: client, consumer: consumer} do
      connection = insert(:connection, client: client, consumer: consumer)

      data =
        conn
        |> patch(client_connection_path(conn, :refresh_secret, client, connection))
        |> json_response(200)
        |> Map.get("data")

      assert Map.has_key?(data, "secret")
      %{secret: new_secret} = Clients.get_connection!(connection.id)
      assert new_secret == data["secret"]
      refute connection.secret == new_secret
    end

    test "invalid redirect uri", %{conn: conn, client: client, consumer: consumer} do
      attrs = %{redirect_uri: "invalid url", consumer_id: consumer.id}

      errors =
        conn
        |> put(client_connection_path(conn, :upsert, client), attrs)
        |> json_response(422)
        |> get_in(~w(error invalid))

      assert "$.redirect_uri" == hd(errors)["entry"]
    end

    test "invalid client_id", %{conn: conn, consumer: consumer} do
      attrs = %{redirect_uri: "http://localhost", consumer_id: consumer.id}

      conn
      |> put(client_connection_path(conn, :upsert, "invalid"), attrs)
      |> json_response(404)
    end

    test "consumer_id not exists", %{conn: conn, client: client} do
      attrs = %{redirect_uri: "http://localhost", consumer_id: UUID.generate()}

      errors =
        conn
        |> put(client_connection_path(conn, :upsert, client), attrs)
        |> json_response(422)
        |> get_in(~w(error invalid))

      assert "$.consumer_id" == hd(errors)["entry"]
    end

    test "invalid consumer_id", %{conn: conn, client: client} do
      attrs = %{redirect_uri: "http://localhost", consumer_id: "invalid"}

      conn
      |> put(client_connection_path(conn, :upsert, client), attrs)
      |> json_response(404)
    end
  end

  describe "update connection" do
    setup %{conn: conn} do
      client = insert(:client)
      consumer = insert(:client)
      {:ok, conn: conn, client: client, consumer: consumer}
    end

    test "success update", %{conn: conn, client: client, consumer: consumer} do
      connection = insert(:connection, client: client, consumer: consumer)
      redirect_uri = "http://example.com"
      attrs = %{secret: "new secret", redirect_uri: redirect_uri}

      conn
      |> patch(client_connection_path(conn, :update, client, connection), attrs)
      |> json_response(200)
      |> assert_connection_fields()

      connection_from_db = Clients.get_connection!(connection.id)
      assert connection.secret == connection_from_db.secret
      assert redirect_uri == connection_from_db.redirect_uri
    end

    test "invalid params", %{conn: conn, client: client, consumer: consumer} do
      connection = insert(:connection, client: client, consumer: consumer)
      attrs = %{redirect_uri: "invalid url", consumer_id: consumer.id}

      errors =
        conn
        |> patch(client_connection_path(conn, :update, client, connection), attrs)
        |> json_response(422)
        |> get_in(~w(error invalid))

      assert "$.redirect_uri" == hd(errors)["entry"]
    end
  end

  describe "delete connections" do
    test "success", %{conn: conn} do
      connection = insert(:connection)

      conn
      |> delete(client_connection_path(conn, :delete, connection.client_id, connection))
      |> response(204)

      assert_error_sent(404, fn ->
        get(conn, client_connection_path(conn, :show, connection.client_id, UUID.generate()))
      end)
    end

    test "not found", %{conn: conn} do
      connection = insert(:connection)

      assert_error_sent(404, fn ->
        delete(conn, client_connection_path(conn, :delete, connection.client_id, UUID.generate()))
      end)
    end
  end

  defp assert_connection_fields(%{"data" => connection}), do: assert_connection_fields(connection)

  defp assert_connection_fields(connection) do
    refute Map.has_key?(connection, "secret")
    fields = ~w(id redirect_uri client_id consumer_id)

    Enum.each(fields, fn field ->
      err_msg = "Response for connection doesn't contains field `#{field}}`"
      assert Map.has_key?(connection, field), err_msg
    end)

    connection
  end
end