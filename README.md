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

# Seed

## Seed Pepperplate Recipes

Usage:

```
  mix run priv/repo/seed_recipes.exs <user_id> <path_to_recipes>
```

An example

```
  mix run priv/repo/seed_recipes.exs 1 /Users/lio/projects/prj.nota/pepperplate_recipes
```
