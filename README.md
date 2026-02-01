# Nota

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## S3/MinIO Setup for Image Uploads

Media files (images) are stored in S3-compatible storage. For local development, we use MinIO.

### Development Setup (MinIO)

1. Add MinIO to your `docker-compose.yml`:

```yaml
services:
  minio:
    image: minio/minio
    ports:
      - "9099:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: root
      MINIO_ROOT_PASSWORD: root421-
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data

volumes:
  minio_data:
```

2. Start MinIO:

```bash
docker-compose up -d minio
```

3. Create the bucket (first time only):

```bash
docker exec -it <minio_container> mc alias set local http://localhost:9000 root root421-
docker exec -it <minio_container> mc mb local/nota-media
docker exec -it <minio_container> mc anonymous set download local/recipe-images
```

The development configuration in `config/config.exs` is pre-configured for this setup.

### Production Setup

Set the following environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `S3_BUCKET` | Bucket name | `recipe-images` |
| `S3_REGION` | AWS region | `us-east-1` |
| `S3_HOST` | S3 endpoint host | `s3.amazonaws.com` |
| `S3_PORT` | S3 endpoint port | `443` |
| `S3_SCHEME` | URL scheme | `https://` |
| `AWS_ACCESS_KEY_ID` | AWS access key | - |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | - |

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

### favicon setup

I used https://favicon.io/favicon-converter/
added  this to lib/nota_web/components/layouts/root.html.heex

```elixir
<link rel="icon" href="/favicon.ico" sizes="48x48" />
<link rel="apple-touch-icon" sizes="180x180" href={~s"/apple-touch-icon.png"} />
<link rel="icon" type="image/png" sizes="32x32" href={~s"/favicon-32x32.png"} />
<link rel="icon" type="image/png" sizes="16x16" href={~s"/favicon-16x16.png"} />
<link rel="manifest" href={~s"/site.webmanifest"} />
```
and edited the site.webmanifest

```
{"name":"PaxNota","short_name":"PaxNota","icons":[{"src":"/android-chrome-192x192.png","sizes":"192x192","type":"image/png"},{"src":"/android-chrome-512x512.png","sizes":"512x512","type":"image/png"}],"theme_color":"#ffffff","background_color":"#ffffff","display":"standalone"}
```


# Seed
