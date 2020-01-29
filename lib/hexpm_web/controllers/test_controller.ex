defmodule HexpmWeb.TestController do
  use HexpmWeb, :controller

  def registry(conn, _params) do
    registry = Hexpm.Store.get(:repo_bucket, "registry.ets.gz", [])

    if signature = Hexpm.Store.get(:repo_bucket, "registry.ets.gz.signed", []) do
      conn
      |> put_resp_header("x-hex-signature", signature)
      |> send_resp(200, registry)
    else
      send_resp(conn, 200, registry)
    end
  end

  def registry_signed(conn, _params) do
    Hexpm.Store.get(:repo_bucket, "registry.ets.gz.signed", [])
    |> send_object(conn)
  end

  def names(conn, _params) do
    Hexpm.Store.get(:repo_bucket, "names", [])
    |> send_object(conn)
  end

  def versions(conn, _params) do
    Hexpm.Store.get(:repo_bucket, "versions", [])
    |> send_object(conn)
  end

  def package(conn, %{"repository" => repository, "package" => package}) do
    Hexpm.Store.get(:repo_bucket, "repos/#{repository}/packages/#{package}", [])
    |> send_object(conn)
  end

  def package(conn, %{"package" => package}) do
    Hexpm.Store.get(:repo_bucket, "packages/#{package}", [])
    |> send_object(conn)
  end

  def tarball(conn, %{"repository" => repository, "ball" => ball}) do
    Hexpm.Store.get(:repo_bucket, "repos/#{repository}/tarballs/#{ball}", [])
    |> send_object(conn)
  end

  def tarball(conn, %{"ball" => ball}) do
    Hexpm.Store.get(:repo_bucket, "tarballs/#{ball}", [])
    |> send_object(conn)
  end

  def repo(conn, params) do
    {:ok, organization} =
      Organizations.create(conn.assigns.current_user, params, audit: {%User{}, "TEST"})

    organization
    |> Ecto.Changeset.change(%{billing_active: true})
    |> Hexpm.Repo.update!()

    send_resp(conn, 204, "")
  end

  def installs_csv(conn, _params) do
    send_resp(conn, 200, "")
  end

  defp send_object(nil, conn), do: send_resp(conn, 404, "")
  defp send_object(obj, conn), do: send_resp(conn, 200, obj)
end
