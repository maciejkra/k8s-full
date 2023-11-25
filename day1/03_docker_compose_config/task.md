# TASK

We have such `docker-compose.yaml` file
```yaml
services:
  python-api:
    image: krajewskim/python-api:new
    ports:
      - 5002:5002
    environment:
      LOG_LEVEL: DEBUG
      REDIS_HOST: redis
  redis:
    image: "redis:alpine"
    volumes:
      - db_data:/data
volumes:
  db_data:
```

What is the best way to manage configuration if we want to have multiple environments with different config and different ports exposed (for example in dev we want to expose redis ports)?